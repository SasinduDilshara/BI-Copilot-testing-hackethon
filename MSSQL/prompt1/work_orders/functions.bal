import ballerina/lang.runtime;
import ballerina/log;
import ballerina/sql;

// Inserts the technician's GPS check-in as a native geography Point (SRID 4326)
// into the work_order_completions table. STGeomFromText is used with the WKT
// bound as an ordinary parameter, so the query remains fully parameterized.
transactional function insertWorkOrderCompletion(WorkOrderCompletionEvent event) returns error? {
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

// Decrements stock for each consumed part in the parts_inventory database, as
// part of the same distributed transaction as the work-order insert.
transactional function decrementPartsInventory(PartConsumed[] partsConsumed) returns error? {
    foreach PartConsumed part in partsConsumed {
        sql:ParameterizedQuery updateQuery = `
            UPDATE parts_inventory
            SET quantity_on_hand = quantity_on_hand - ${part.quantity}
            WHERE sku = ${part.sku}`;
        _ = check partsInventoryDbClient->execute(updateQuery);
    }
}

// Runs the work-order completion insert and the inventory decrement in a single
// distributed (XA) transaction so both either commit or roll back together.
function persistWorkOrderCompletion(WorkOrderCompletionEvent event) returns error? {
    transaction {
        check insertWorkOrderCompletion(event);
        check decrementPartsInventory(event.partsConsumed);
        check commit;
    }
}

// Attempts to persist the work-order completion, retrying the whole distributed
// transaction up to maxTransactionRetries times with exponential backoff on
// transient failures. If every attempt fails, the raw event and the last error
// are written to the dead-letter queue instead of being lost. Returns an error
// only if even the dead-letter write itself fails.
function processWorkOrderCompletion(WorkOrderCompletionEvent event) returns CompletionPersisted|CompletionSentToDlq|error {
    int attempt = 0;
    while true {
        error? result = persistWorkOrderCompletion(event);
        if result is () {
            return {};
        }

        attempt += 1;
        log:printWarn("Work-order completion transaction attempt failed",
                workOrderId = event.workOrderId, attempt = attempt, 'error = result);

        if attempt >= maxTransactionRetries {
            check writeToDeadLetterQueue(event, result);
            return {cause: result};
        }

        decimal backoffSeconds = retryBaseDelaySeconds * (2 ^ (attempt - 1));
        runtime:sleep(backoffSeconds);
    }
}

// Writes the raw event and the error that caused the final failure to the
// workorder_completions_dlq table so that the event is not lost.
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
