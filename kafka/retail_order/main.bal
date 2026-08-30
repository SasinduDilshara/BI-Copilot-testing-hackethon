import ballerina/log;
import ballerinax/kafka;

const string ORDER_PROCESSING_GROUP = "order-processing-service";
const string ORDERS_CREATED_TOPIC = "orders.created";

kafka:ConsumerConfiguration orderConsumerConfiguration = {
    groupId: ORDER_PROCESSING_GROUP,
    topics: [ORDERS_CREATED_TOPIC],
    offsetReset: "earliest",
    autoCommit: false,
    pollingInterval: 1
};

listener kafka:Listener orderKafkaListener = new (kafkaBootstrapServers, orderConsumerConfiguration);

service kafka:Service on orderKafkaListener {

    remote function onConsumerRecord(kafka:Caller caller, OrderEventConsumerRecord[] records) returns error? {
        foreach OrderEventConsumerRecord orderEventRecord in records {
            handleOrderEventRecord(orderEventRecord);
        }

        kafka:Error? commitResult = caller->commit();
        if commitResult is kafka:Error {
            log:printError("Failed to commit offsets for the processed batch", 'error = commitResult);
            return commitResult;
        }
        log:printInfo("Successfully processed batch", batchSize = records.length());
    }

    remote function onError(kafka:Error err) returns error? {
        log:printError("Error while consuming order events", 'error = err);
    }
}

// Handles a single order event record end-to-end: malformed payloads (including
// ones missing the customer fields) are routed straight to the DLQ, and any
// publish failure for a valid event also falls straight back to the DLQ since
// there is nothing transient left to retry. A single bad record never prevents
// the rest of the batch, or the batch commit, from proceeding.
function handleOrderEventRecord(OrderEventConsumerRecord orderEventRecord) {
    OrderEvent orderEvent = orderEventRecord.value;
    byte[] rawValue = orderEvent.toJsonString().toBytes();

    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    if validationError is InvalidOrderEventError {
        log:printWarn("Order event failed validation, routing to DLQ",
                orderId = orderEvent.orderId, 'error = validationError);
        error? dlqResult = publishToDlq(rawValue, validationError.message(), orderEvent.orderId);
        if dlqResult is error {
            log:printError("Failed to route invalid order event to DLQ", 'error = dlqResult,
                    orderId = orderEvent.orderId);
        }
        return;
    }

    EnrichedOrder enrichedOrder = toEnrichedOrder(orderEvent);
    error? publishResult = publishEnrichedOrder(enrichedOrder);
    if publishResult is error {
        log:printError("Failed to publish enriched order, routing to DLQ",
                'error = publishResult, orderId = orderEvent.orderId);
        error? dlqResult = publishToDlq(rawValue, publishResult.message(), orderEvent.orderId);
        if dlqResult is error {
            log:printError("Failed to route failed order event to DLQ", 'error = dlqResult,
                    orderId = orderEvent.orderId);
        }
    }
}
