import ballerina/lang.value;
import ballerina/log;
import ballerinax/rabbitmq;

# Consumes inventory reservation replies from the shared `fulfilment.replies` queue, correlates
# each one back to its originating saga using the message's correlation ID, and advances (or
# fails and compensates) that saga accordingly. This decouples the HTTP request from the
# reservation round-trip: `POST /fulfilment/orders` returns as soon as the request is published,
# and this consumer drives the saga forward whenever the inventory responder eventually replies.
@rabbitmq:ServiceConfig {
    queueName: FULFILMENT_REPLIES_QUEUE,
    autoAck: false
}
service rabbitmq:Service on repliesQueueListener {
    remote function onMessage(rabbitmq:AnydataMessage message, rabbitmq:Caller caller) returns error? {
        rabbitmq:BasicProperties? replyProperties = message?.properties;
        string? correlationId = replyProperties is rabbitmq:BasicProperties ? replyProperties?.correlationId : ();
        if correlationId is () {
            log:printError("Received a reservation reply without a correlation ID; dropping.");
            check caller->basicNack(requeue = false);
            return;
        }

        ReservationResponse|error reservationResponse = value:ensureType(message.content);
        if reservationResponse is error {
            log:printError(string `Failed to decode reservation reply for correlation ID ${correlationId}: ${reservationResponse.message()}`);
            check caller->basicNack(requeue = false);
            return;
        }

        handleReservationReply(correlationId, reservationResponse);
        check caller->basicAck();
    }
}
