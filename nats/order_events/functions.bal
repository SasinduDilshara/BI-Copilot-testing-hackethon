import ballerina/log;
import ballerinax/nats;

// Creates the ORDERS stream if it does not exist, or loads the existing one otherwise.
function initOrdersStream() returns nats:Error? {
    check jetStreamClient->addStream(ordersStreamConfig);
}

// Publishes a typed order event to the subject orders.created.
function publishOrderCreatedEvent(OrderEvent orderEvent) returns nats:Error? {
    byte[] content = orderEvent.toJsonString().toBytes();
    nats:JetStreamMessage message = {
        content,
        subject: "orders.created"
    };
    check jetStreamClient->publishMessage(message);
}

// Converts the anydata content of a consumed JetStream service message into a typed OrderEvent.
function anydataToOrderEvent(anydata content) returns OrderEvent|error {
    if content is byte[] {
        string payload = check string:fromBytes(content);
        json orderEventJson = check payload.fromJsonString();
        return orderEventJson.cloneWithType(OrderEvent);
    }
    return content.cloneWithType(OrderEvent);
}

// Persists the order to a datastore. Replace with the actual persistence logic. A transient
// downstream failure is surfaced as a TransientPersistenceError so it can be distinguished
// from an unparsable/permanent failure.
function persistOrder(OrderEvent orderEvent) returns TransientPersistenceError? {
    log:printInfo(string `Persisting order ${orderEvent.orderId} for customer ${orderEvent.customerId}`);
}
