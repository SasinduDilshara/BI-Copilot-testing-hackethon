import ballerina/http;
import ballerinax/asb;

// HTTP endpoint used to submit a fulfilment command for test purposes.
service /orders on new http:Listener(httpPort) {

    resource function post fulfilCommands(@http:Payload FulfilmentCommand command) returns FulfilmentCommandAcceptedResponse|FulfilmentCommandErrorResponse {
        asb:Message commandMessage = {
            body: command.toJson().toJsonString().toBytes(),
            contentType: "application/json",
            correlationId: command.orderId
        };

        asb:Error? sendResult = orderCommandSender->send(commandMessage);
        if sendResult is asb:Error {
            FulfilmentCommandErrorResponse errorResponse = {
                body: {message: "Failed to submit fulfilment command: " + sendResult.message()}
            };
            return errorResponse;
        }

        FulfilmentCommandAcceptedResponse acceptedResponse = {
            body: {message: "Fulfilment command submitted", orderId: command.orderId}
        };
        return acceptedResponse;
    }

    resource function get health() returns HealthCountersResponse {
        HealthCounters counters = getHealthCounters();
        HealthCountersResponse healthResponse = {
            body: counters
        };
        return healthResponse;
    }
}
