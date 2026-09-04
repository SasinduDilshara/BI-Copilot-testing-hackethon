import ballerina/http;

// HTTP endpoint used to submit a fulfilment command for test purposes.
service /orders on new http:Listener(httpPort) {

    resource function post fulfilCommands(@http:Payload FulfilmentCommand command) returns FulfilmentCommandAcceptedResponse|FulfilmentCommandErrorResponse {
        error? submitResult = submitFulfilmentCommand(command);
        if submitResult is error {
            FulfilmentCommandErrorResponse errorResponse = {
                body: {message: "Failed to submit fulfilment command: " + submitResult.message()}
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
