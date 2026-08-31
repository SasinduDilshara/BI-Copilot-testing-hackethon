import ballerina/log;
import ballerinax/nats;

// Consumes orders.created. Processing is fast, so no in-progress heartbeating is needed.
// A transient persistence failure is logged and returned as an error so the delivery
// is not silently swallowed.
@nats:StreamServiceConfig {
    subject: "orders.created"
}
service on new nats:JetStreamListener(natsClient) {

    remote function onMessage(nats:AnydataMessage message) returns error? {
        OrderEvent|error orderEvent = anydataToOrderEvent(message.content);
        if orderEvent is error {
            log:printError(string `Discarding unparsable message on subject ${message.subject}`,
                    'error = orderEvent);
            return;
        }

        TransientPersistenceError? persistResult = persistOrder(orderEvent);
        if persistResult is TransientPersistenceError {
            log:printWarn(string `Transient failure while persisting order ${orderEvent.orderId}`,
                    'error = persistResult);
            return persistResult;
        }

        log:printInfo(string `Order ${orderEvent.orderId} persisted`);
    }
}
