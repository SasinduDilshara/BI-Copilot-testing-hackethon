import ballerina/log;
import ballerinax/gcloud.pubsub;

// Raised when processing a received order event fails due to a transient
// condition where redelivery is expected to succeed.
type TransientProcessingError distinct error;

// In-memory store standing in for the real processing outcome of an order
// event. Keyed by orderId + eventType so re-processing the same event is
// idempotent.
final map<OrderEvent> processedOrderEvents = {};

// In-memory delivery-attempt counters keyed by message ID. The installed
// ballerinax/gcloud.pubsub connector does not expose a delivery-attempt count
// on received messages and has no admin API to configure a dead-letter policy
// on the subscription, so this counter is tracked entirely in application
// code: it increments each time a message is redelivered, is reported on
// every receive, and drives when a message is routed to the poison topic
// instead of being nacked again.
final map<int> deliveryAttemptsByMessageId = {};

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

// Returns a message identity to key the local delivery-attempt counter by.
// Falls back to a hex encoding of the message content when the broker does
// not set a messageId, so every message can still be tracked.
function messageDeliveryKey(pubsub:Message message) returns string {
    string? messageId = message.messageId;
    if messageId is string {
        return messageId;
    }
    return message.data.toBase16();
}

// Increments and returns the local delivery-attempt count for a message.
// Called once per received message so the very first delivery is reported as
// attempt 1.
function recordDeliveryAttempt(pubsub:Message message) returns int {
    string key = messageDeliveryKey(message);
    lock {
        int currentCount = deliveryAttemptsByMessageId[key] ?: 0;
        int updatedCount = currentCount + 1;
        deliveryAttemptsByMessageId[key] = updatedCount;
        return updatedCount;
    }
}

// Clears the local delivery-attempt count for a message once it has been
// acknowledged, since it will not be redelivered.
function clearDeliveryAttempts(pubsub:Message message) {
    string key = messageDeliveryKey(message);
    lock {
        _ = deliveryAttemptsByMessageId.removeIfHasKey(key);
    }
}

// Republishes a message to the poison topic, carrying the original message
// attributes plus the failure reason and the number of delivery attempts
// made, then logs the message ID returned by the broker.
function publishToPoisonTopic(pubsub:Message message, int deliveryAttempt, string failureReason) returns error? {
    map<string> attributes = message.attributes is map<string> ? (<map<string>>message.attributes).clone() : {};
    attributes["failureReason"] = failureReason;
    attributes["deliveryAttempts"] = deliveryAttempt.toString();

    pubsub:Message poisonMessage = {
        data: message.data,
        attributes: attributes
    };

    string messageId = check poisonEventPublisher->publish(poisonMessage);
    log:printWarn("Published exhausted order event message to poison topic", messageId = messageId,
            deliveryAttempt = deliveryAttempt, maxDeliveryAttempts = maxDeliveryAttempts,
            failureReason = failureReason);
}

// Processes a single incoming Pub/Sub message: reconstructs the order event,
// processes it, and acks/nacks the caller accordingly. Extracted from the
// service so the acknowledgement behavior can be exercised directly in tests
// with a mocked caller.
function handleIncomingOrderEvent(pubsub:Message message, pubsub:Caller caller) returns error? {
    int deliveryAttempt = recordDeliveryAttempt(message);

    OrderEvent|error orderEvent = toOrderEvent(message);
    if orderEvent is error {
        log:printError("Discarding malformed order event message", orderEvent,
                deliveryAttempt = deliveryAttempt, maxDeliveryAttempts = maxDeliveryAttempts);
        clearDeliveryAttempts(message);
        check caller->ack();
        return;
    }

    log:printInfo("Received order event", orderId = orderEvent.orderId, eventType = orderEvent.eventType,
            deliveryAttempt = deliveryAttempt, maxDeliveryAttempts = maxDeliveryAttempts);

    TransientProcessingError? processResult = processOrderEvent(orderEvent);
    if processResult is TransientProcessingError {
        if deliveryAttempt >= maxDeliveryAttempts {
            check publishToPoisonTopic(message, deliveryAttempt, processResult.message());
            clearDeliveryAttempts(message);
            check caller->ack();
            return;
        }

        log:printWarn("Transient failure processing order event, requesting redelivery",
                processResult, orderId = orderEvent.orderId, eventType = orderEvent.eventType,
                deliveryAttempt = deliveryAttempt, maxDeliveryAttempts = maxDeliveryAttempts);
        check caller->nack();
        return;
    }

    clearDeliveryAttempts(message);
    check caller->ack();
}
