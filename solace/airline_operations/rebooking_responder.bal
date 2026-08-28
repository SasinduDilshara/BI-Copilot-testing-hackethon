import ballerina/log;
import ballerinax/solace;

# Consumes passenger rebooking requests published on `airline/rebooking/request/{carrierCode}` and
# publishes a typed `RebookingResponse` back to the reply-to destination of the request, carrying
# the same correlation ID so the original requester can match the reply.
@solace:ServiceConfig {
    topicName: "airline/rebooking/request/*"
}
service on rebookingListener {

    # Invoked for every rebooking request delivered on the request topic hierarchy.
    #
    # + message - The rebooking request message, with the payload data-bound into `RebookingRequest`
    # + return - A `solace:Error` if the reply cannot be published
    remote function onMessage(RebookingRequestMessage message) returns solace:Error? {
        RebookingRequest rebookingRequest = message.payload;
        solace:Destination? replyTo = message?.replyTo;
        string? correlationId = message?.correlationId;

        if replyTo is () || correlationId is () {
            log:printWarn("Rebooking request received without a reply-to destination or correlation ID, ignoring",
                    passengerId = rebookingRequest.passengerId);
            return;
        }

        RebookingResponse rebookingResponse = resolveRebooking(rebookingRequest);

        solace:Message replyMessage = {
            payload: rebookingResponse,
            deliveryMode: solace:PERSISTENT,
            correlationId
        };

        check solaceProducer->send(replyMessage, replyTo);
        log:printInfo("Rebooking response published", passengerId = rebookingRequest.passengerId,
                correlationId = correlationId);
    }

    # Invoked when a delivered message cannot be dispatched to `onMessage`, most commonly because the
    # underlying guaranteed consumer flow is disrupted.
    #
    # + err - The failure that prevented dispatch
    remote function onError(solace:Error err) returns solace:Error? {
        if err is solace:FlowDownError {
            log:printError("Rebooking responder flow is down; the underlying connection was lost " +
                    "and the flow will be re-established once connectivity is restored", 'error = err);
            return;
        }

        if err is solace:InactiveFlowError {
            log:printWarn("Rebooking responder flow is inactive; another instance in the client " +
                    "cluster is likely active and this instance will remain on standby", 'error = err);
            return;
        }

        log:printError("Unexpected error while consuming rebooking requests", 'error = err);
    }
}
