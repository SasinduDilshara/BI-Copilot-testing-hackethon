import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/sql;
import ballerinax/kafka;

// Derives a stable idempotency key from the work order ID. Because the same
// work order ID always yields the same key, redelivering or retrying the same
// completion event can never cause the inventory service to double-decrement
// stock - the inventory service is expected to dedupe on this key.
function idempotencyKeyFor(WorkOrderCompletionEvent event) returns string {
    return string `wo-completion:${event.workOrderId}`;
}

// Inserts the technician's GPS check-in as a native geography Point (SRID 4326)
// into the work_order_completions table. STGeomFromText is used with the WKT
// bound as an ordinary parameter, so the query remains fully parameterized.
function insertWorkOrderCompletion(WorkOrderCompletionEvent event) returns error? {
    string pointWkt = string `POINT(${event.gpsCheckIn.longitude} ${event.gpsCheckIn.latitude})`;
    string partsConsumedJson = event.partsConsumed.toJsonString();

    sql:ParameterizedQuery insertQuery = `
        INSERT INTO work_order_completions
            (work_order_id, technician_id, gps_check_in, parts_consumed_json)
        VALUES
            (${event.workOrderId}, ${event.technicianId},
             geography::STGeomFromText(${pointWkt}, 4326), ${partsConsumedJson})`;
    _ = check workOrdersDbClient->execute(insertQuery);
}

// Inserts the compensating decrement-stock message into the outbox table in
// the work-order database, in the same local transaction as the work-order
// completion insert. idempotency_key has a unique constraint, so retrying the
// same event is safe - the duplicate insert is simply ignored.
function insertOutboxMessage(DecrementStockMessage decrementStockMessage) returns error? {
    string partsConsumedJson = decrementStockMessage.partsConsumed.toJsonString();

    sql:ParameterizedQuery insertQuery = `
        IF NOT EXISTS (
            SELECT 1 FROM outbox_messages WHERE idempotency_key = ${decrementStockMessage.idempotencyKey}
        )
        INSERT INTO outbox_messages
            (idempotency_key, work_order_id, parts_consumed_json, status)
        VALUES
            (${decrementStockMessage.idempotencyKey}, ${decrementStockMessage.workOrderId},
             ${partsConsumedJson}, 'PENDING')`;
    _ = check workOrdersDbClient->execute(insertQuery);
}

// Marks an outbox message as published after it has been handed off to Kafka.
function markOutboxMessagePublished(string idempotencyKey) returns error? {
    sql:ParameterizedQuery updateQuery = `
        UPDATE outbox_messages
        SET status = 'PUBLISHED', published_time = SYSUTCDATETIME()
        WHERE idempotency_key = ${idempotencyKey}`;
    _ = check workOrdersDbClient->execute(updateQuery);
}

// Persists the work-order completion and the outbox message in a single local
// transaction against the work-order database only. Since both writes target
// the same database, this is an ordinary ACID transaction - no XA/MSDTC is
// required.
function persistWorkOrderCompletion(WorkOrderCompletionEvent event, DecrementStockMessage decrementStockMessage) returns error? {
    transaction {
        check insertWorkOrderCompletion(event);
        check insertOutboxMessage(decrementStockMessage);
        check commit;
    }
}

// Publishes the decrement-stock message to Kafka, keyed by the idempotency
// key so the inventory service can dedupe retried/redelivered messages and
// never double-decrement stock. On success, the outbox row is marked
// published; if publishing fails, the row is left PENDING so an outbox relay
// process can retry the send later without losing the message.
function publishDecrementStockMessage(DecrementStockMessage decrementStockMessage) returns error? {
    kafka:Error? sendResult = decrementStockProducer->send({
        topic: decrementStockTopic,
        key: decrementStockMessage.idempotencyKey.toBytes(),
        value: decrementStockMessage.toJsonString().toBytes()
    });
    if sendResult is kafka:Error {
        return sendResult;
    }
    check markOutboxMessagePublished(decrementStockMessage.idempotencyKey);
}

// Attempts to persist the work-order completion and its outbox message,
// retrying the local transaction up to maxTransactionRetries times with
// exponential backoff on transient failures. Once the local transaction
// commits, the decrement-stock message is published to Kafka. If every
// persistence attempt fails, the existing /incidents/report webhook is called
// so it can page on-call with the failure details; only if that webhook call
// itself fails is the raw event and error written to the dead-letter queue as
// a last resort. Returns an error only if even the dead-letter write fails.
function processWorkOrderCompletion(WorkOrderCompletionEvent event) returns CompletionPersisted|CompletionReportedAsIncident|CompletionSentToDlq|error {
    DecrementStockMessage decrementStockMessage = {
        idempotencyKey: idempotencyKeyFor(event),
        workOrderId: event.workOrderId,
        partsConsumed: event.partsConsumed
    };

    int attempt = 0;
    while true {
        error? result = persistWorkOrderCompletion(event, decrementStockMessage);
        if result is () {
            break;
        }

        attempt += 1;
        log:printWarn("Work-order completion transaction attempt failed",
                workOrderId = event.workOrderId, attempt = attempt, 'error = result);

        if attempt >= maxTransactionRetries {
            return handleExhaustedRetries(event, result);
        }

        decimal backoffSeconds = retryBaseDelaySeconds * (2 ^ (attempt - 1));
        runtime:sleep(backoffSeconds);
    }

    // The local transaction has committed, so the outbox message is durable.
    // A best-effort publish is attempted immediately; if it fails, the row
    // remains PENDING in the outbox table for later redelivery, so the
    // message is never lost.
    error? publishResult = publishDecrementStockMessage(decrementStockMessage);
    if publishResult is error {
        log:printWarn("Failed to publish decrement-stock message, it remains queued in the outbox",
                workOrderId = event.workOrderId, 'error = publishResult);
    }

    return {outcome: "PERSISTED"};
}

// Called once the local transaction has failed on every retry attempt. Pages
// on-call via the existing incidents webhook; only falls back to the
// dead-letter table if that webhook call itself fails.
function handleExhaustedRetries(WorkOrderCompletionEvent event, error cause) returns CompletionReportedAsIncident|CompletionSentToDlq|error {
    error? incidentResult = reportIncident(event, cause);
    if incidentResult is () {
        return {outcome: "INCIDENT_REPORTED", cause};
    }

    log:printWarn("Failed to report incident to the on-call webhook, writing to the dead-letter queue instead",
            workOrderId = event.workOrderId, 'error = incidentResult);
    check writeToDeadLetterQueue(event, cause);
    return {outcome: "DEAD_LETTERED", cause};
}

// Calls the existing /incidents/report webhook so it can page on-call with
// the failure details.
function reportIncident(WorkOrderCompletionEvent event, error cause) returns error? {
    IncidentReport incidentReport = {
        workOrderId: event.workOrderId,
        technicianId: event.technicianId,
        rawEvent: event.toJsonString(),
        errorMessage: cause.message()
    };
    http:Response|http:ClientError response = incidentsServiceClient->/incidents/report.post(incidentReport);
    if response is http:ClientError {
        return response;
    }
}

// Writes the raw event and the error that caused the final failure to the
// workorder_completions_dlq table so that the event is not lost. This is only
// used as a last resort when the incidents webhook call itself fails.
function writeToDeadLetterQueue(WorkOrderCompletionEvent event, error cause) returns error? {
    string rawEventJson = event.toJsonString();
    string errorMessage = cause.message();

    sql:ParameterizedQuery dlqInsertQuery = `
        INSERT INTO workorder_completions_dlq
            (work_order_id, raw_event_json, error_message)
        VALUES
            (${event.workOrderId}, ${rawEventJson}, ${errorMessage})`;
    _ = check workOrdersDbClient->execute(dlqInsertQuery);
}
