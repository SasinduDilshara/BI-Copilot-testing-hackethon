import ballerina/log;
import ballerinax/gcloud.pubsub;

// Raised when processing a received order event fails due to a transient
// condition where redelivery is expected to succeed.
type TransientProcessingError distinct error;

// In-memory store standing in for the real processing outcome of an order
// event. Keyed by orderId + eventType so re-processing the same event is
// idempotent.
final map<OrderEvent> processedOrderEvents = {};

// Order ID reserved for exercising the transient-failure/nack path in tests;
// processing always fails transiently for events with this order ID.
const string TRANSIENT_FAILURE_TEST_ORDER_ID = "test-transient-failure-order";

// Publishes an order event to the configured Pub/Sub topic and logs the
// message ID returned by the broker.
function publishOrderEvent(OrderEvent orderEvent) returns error? {
    byte[] data = orderEvent.toJsonString().toBytes();

    pubsub:Message message = {
        data: data
    };

    string messageId = check orderEventPublisher->publish(message);
    log:printInfo("Published order event", messageId = messageId, orderId = orderEvent.orderId,
            eventType = orderEvent.eventType);
}

// Reconstructs an OrderEvent from a received Pub/Sub message payload.
function toOrderEvent(pubsub:Message message) returns OrderEvent|error {
    string payloadText = check string:fromBytes(message.data);
    return payloadText.fromJsonStringWithType(OrderEvent);
}

// Builds the processing store key for an order event. Using orderId +
// eventType makes processing a redelivered event idempotent.
function orderEventStorageKey(OrderEvent orderEvent) returns string =>
    string:'join("|", orderEvent.orderId, orderEvent.eventType);

// Processes a received order event. Any other error is treated as permanent.
function processOrderEvent(OrderEvent orderEvent) returns TransientProcessingError? {
    if orderEvent.orderId == TRANSIENT_FAILURE_TEST_ORDER_ID {
        return error TransientProcessingError("simulated transient processing failure");
    }

    string key = orderEventStorageKey(orderEvent);
    lock {
        processedOrderEvents[key] = orderEvent.clone();
    }
    log:printInfo("Processed order event", orderId = orderEvent.orderId, eventType = orderEvent.eventType);
}

// Returns the order event processed for the given order ID and event type,
// if any.
function getProcessedOrderEvent(string orderId, string eventType) returns OrderEvent? {
    string key = string:'join("|", orderId, eventType);
    lock {
        return processedOrderEvents[key];
    }
}

// Processes a single incoming Pub/Sub message: reconstructs the order event,
// processes it, and acks/nacks the caller accordingly. Extracted from the
// service so the acknowledgement behavior can be exercised directly in tests
// with a mocked caller.
function handleIncomingOrderEvent(pubsub:Message message, pubsub:Caller caller) returns error? {
    OrderEvent|error orderEvent = toOrderEvent(message);
    if orderEvent is error {
        log:printError("Discarding malformed order event message", orderEvent);
        check caller->ack();
        return;
    }

    TransientProcessingError? processResult = processOrderEvent(orderEvent);
    if processResult is TransientProcessingError {
        log:printWarn("Transient failure processing order event, requesting redelivery",
                processResult, orderId = orderEvent.orderId, eventType = orderEvent.eventType);
        check caller->nack();
        return;
    }

    check caller->ack();
}
