import ballerina/log;
import ballerinax/asb;

function init() returns error? {
    check provisionServiceBusEntities();
}

// Receives fulfilment commands from the orders-to-fulfil queue and publishes the
// resulting fulfilment status to the order-status topic.
service asb:Service on orderCommandListener {

    remote function onMessage(asb:Message message) returns error? {
        anydata messageBody = message.body;
        FulfilmentCommand|error command = parseFulfilmentCommand(messageBody);
        if command is error {
            log:printError("Failed to bind message body to FulfilmentCommand", command);
            return;
        }

        log:printInfo("Received fulfilment command", orderId = command.orderId);

        FulfilmentStatus status = {
            orderId: command.orderId,
            status: "FULFILLED",
            message: string `Order ${command.orderId} has been processed for fulfilment`,
            updatedAt: getCurrentTimestamp()
        };

        check publishFulfilmentStatus(status, command.orderId);
    }

    remote function onError(asb:MessageRetrievalError 'error, error asbError) returns error? {
        string retrievalErrorMessage = 'error.message();
        log:printError("Error occurred while receiving messages from ASB", 'error, retrievalErrorMessage = retrievalErrorMessage);
    }
}
