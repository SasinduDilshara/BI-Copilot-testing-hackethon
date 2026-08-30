import ballerina/log;
import ballerinax/kafka;

const string ORDERS_ENRICHED_TOPIC = "orders.enriched";
const string ORDERS_DLQ_TOPIC = "orders.dlq";

// Validates the structural integrity of an order event, including the customer
// fields that must now be present on the event itself. Returns an
// `InvalidOrderEventError` when the payload is malformed and must not be retried.
function validateOrderEvent(OrderEvent orderEvent) returns InvalidOrderEventError? {
    if orderEvent.orderId.trim().length() == 0 {
        return error InvalidOrderEventError("Order event is missing orderId");
    }
    if orderEvent.customerId.trim().length() == 0 {
        return error InvalidOrderEventError("Order event is missing customerId", orderId = orderEvent.orderId);
    }
    if orderEvent.orderAmount <= 0d {
        return error InvalidOrderEventError("Order event has a non-positive orderAmount",
                orderId = orderEvent.orderId);
    }
    if orderEvent.currency.trim().length() == 0 {
        return error InvalidOrderEventError("Order event is missing currency", orderId = orderEvent.orderId);
    }
    if orderEvent.itemCount <= 0 {
        return error InvalidOrderEventError("Order event has a non-positive itemCount",
                orderId = orderEvent.orderId);
    }
    if orderEvent.channel.trim().length() == 0 {
        return error InvalidOrderEventError("Order event is missing channel", orderId = orderEvent.orderId);
    }
    if orderEvent.customerTier.trim().length() == 0 {
        return error InvalidOrderEventError("Order event is missing customerTier", orderId = orderEvent.orderId);
    }
    if orderEvent.customerEmail.trim().length() == 0 {
        return error InvalidOrderEventError("Order event is missing customerEmail", orderId = orderEvent.orderId);
    }
    if orderEvent.customerCountry.trim().length() == 0 {
        return error InvalidOrderEventError("Order event is missing customerCountry", orderId = orderEvent.orderId);
    }
    return;
}

// Maps an order event to its enriched form using the customer fields carried on the event.
function toEnrichedOrder(OrderEvent orderEvent) returns EnrichedOrder => {
    orderId: orderEvent.orderId,
    customerId: orderEvent.customerId,
    orderAmount: orderEvent.orderAmount,
    currency: orderEvent.currency,
    itemCount: orderEvent.itemCount,
    channel: orderEvent.channel,
    customerTier: orderEvent.customerTier,
    customerEmail: orderEvent.customerEmail,
    customerCountry: orderEvent.customerCountry
};

// Publishes the enriched order to the `orders.enriched` topic.
function publishEnrichedOrder(EnrichedOrder enrichedOrder) returns error? {
    kafka:Error? sendResult = orderEventProducer->send({
        topic: ORDERS_ENRICHED_TOPIC,
        key: enrichedOrder.orderId.toBytes(),
        value: enrichedOrder.toJson().toJsonString().toBytes()
    });
    if sendResult is kafka:Error {
        return sendResult;
    }
    return;
}

// Publishes a failed record to the `orders.dlq` topic with the failure reason in the headers.
function publishToDlq(byte[] rawValue, string failureReason, string orderId) returns error? {
    kafka:Error? sendResult = orderEventProducer->send({
        topic: ORDERS_DLQ_TOPIC,
        key: orderId.toBytes(),
        value: rawValue,
        headers: {
            "x-failure-reason": failureReason,
            "x-order-id": orderId
        }
    });
    if sendResult is kafka:Error {
        log:printError("Failed to publish record to the DLQ", 'error = sendResult, orderId = orderId);
        return sendResult;
    }
    return;
}
