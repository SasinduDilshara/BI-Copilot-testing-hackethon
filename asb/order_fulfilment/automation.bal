import ballerina/log;
import ballerinax/asb;

function init() returns error? {
    check provisionServiceBusEntities();
}

// Receives fulfilment commands from the orders-to-fulfil queue and publishes the
// resulting fulfilment status to the order-status topic.
service asb:Service on orderCommandListener {

    remote function onMessage(asb:Message message, asb:Caller caller) returns error? {
        anydata messageBody = message.body;
        FulfilmentCommand|error command = parseFulfilmentCommand(messageBody);
        if command is error {
            log:printError("Failed to bind message body to FulfilmentCommand", command);
            check deadLetterCommand(caller, "InvalidCommand", "Message body could not be parsed into a FulfilmentCommand: " + command.message());
            return;
        }

        error? validationResult = validateFulfilmentCommand(command);
        if validationResult is error {
            log:printError("Fulfilment command failed validation", validationResult, orderId = command.orderId);
            check deadLetterCommand(caller, "InvalidCommand", validationResult.message());
            return;
        }

        log:printInfo("Received fulfilment command", orderId = command.orderId);

        FulfilmentStatus status = {
            orderId: command.orderId,
            status: "FULFILLED",
            message: string `Order ${command.orderId} has been processed for fulfilment`,
            updatedAt: getCurrentTimestamp()
        };

        string? commandRegion = command.region;
        string statusRegion = commandRegion is string ? commandRegion : region;
        error? publishResult = publishFulfilmentStatus(status, command.orderId, statusRegion);
        if publishResult is error {
            log:printError("Failed to publish fulfilment status; abandoning message for retry", publishResult, orderId = command.orderId);
            asb:Error? abandonResult = caller->abandon({});
            if abandonResult is asb:Error {
                log:printError("Failed to abandon message", abandonResult, orderId = command.orderId);
                return abandonResult;
            }
            recordAbandoned();
            return;
        }

        asb:Error? completeResult = caller->complete();
        if completeResult is asb:Error {
            log:printError("Failed to complete message after successful status publication", completeResult, orderId = command.orderId);
            return completeResult;
        }
        recordCompleted();
    }

    remote function onError(asb:MessageRetrievalError 'error) returns error? {
        string retrievalErrorMessage = 'error.message();
        log:printError("Error occurred while receiving messages from ASB", 'error, retrievalErrorMessage = retrievalErrorMessage);
    }
}
