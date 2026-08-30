import ballerina/lang.value;
import ballerina/log;
import ballerinax/rabbitmq;

# Simulates a stock check for the given reservation request. Every SKU is treated as in stock
# except for the sentinel SKU `OUT-OF-STOCK`, which always fails the check — this makes it easy
# to exercise the payment/shipping failure and compensation paths from the tests.
#
# + reservationRequest - the reservation request to check stock for
# + return - () when all items are in stock, or an error describing the first shortfall
isolated function checkStock(ReservationRequest reservationRequest) returns error? {
    foreach OrderItem item in reservationRequest.items {
        if item.sku == "OUT-OF-STOCK" || item.quantity <= 0 {
            return error(string `Insufficient stock for SKU ${item.sku} (order ${reservationRequest.orderId})`);
        }
    }
}

# Inventory responder: consumes reservation requests from `inventory.reserve`, checks stock, and
# publishes a `ReservationResponse` back to the request's `replyTo` queue using the same
# correlation ID. The original delivery is only acknowledged after the reply has been
# successfully published, so a crash before the reply goes out results in redelivery instead of
# a silently lost reservation request.
@rabbitmq:ServiceConfig {
    queueName: INVENTORY_RESERVE_QUEUE,
    autoAck: false
}
service rabbitmq:Service on inventoryQueueListener {
    remote function onMessage(rabbitmq:AnydataMessage message, rabbitmq:Caller caller) returns error? {
        ReservationRequest reservationRequest = check value:ensureType(message.content);
        rabbitmq:BasicProperties? requestProperties = message?.properties;

        if requestProperties is () {
            log:printError(string `Reservation request for order ${reservationRequest.orderId} is missing properties; dropping.`);
            check caller->basicNack(requeue = false);
            return;
        }

        string? replyTo = requestProperties?.replyTo;
        string? correlationId = requestProperties?.correlationId;
        if replyTo is () || correlationId is () {
            log:printError(string `Reservation request for order ${reservationRequest.orderId} is missing replyTo/correlationId; dropping.`);
            check caller->basicNack(requeue = false);
            return;
        }

        error? stockCheckResult = checkStock(reservationRequest);
        ReservationResponse reservationResponse = stockCheckResult is error
            ? {orderId: reservationRequest.orderId, reserved: false, message: stockCheckResult.message()}
            : {orderId: reservationRequest.orderId, reserved: true};

        rabbitmq:BasicProperties replyProperties = {
            correlationId: correlationId,
            contentType: "application/json"
        };
        rabbitmq:AnydataMessage replyMessage = {
            content: reservationResponse,
            routingKey: replyTo,
            properties: replyProperties
        };

        rabbitmq:Error? publishResult = rabbitmqClient->publishMessage(replyMessage);
        if publishResult is rabbitmq:Error {
            log:printError(string `Failed to publish reservation reply for order ${reservationRequest.orderId}: ${publishResult.message()}`);
            check caller->basicNack(requeue = true);
            return;
        }

        // Ack only after the reply has been successfully sent back to the caller.
        check caller->basicAck();
    }
}
