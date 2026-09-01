import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/ibm.ibmmq;

service /payments on new http:Listener(servicePort) {

    # Accepts a payment instruction and puts it onto the PAYMENT.INSTRUCTIONS queue.
    # The response is delivered asynchronously by the PAYMENT.RESPONSES consumer.
    #
    # + paymentInstruction - the payment instruction to be queued
    # + return - an accepted acknowledgement on success, or an error response on failure
    resource function post instructions(@http:Payload PaymentInstruction paymentInstruction)
            returns http:Accepted|http:ServiceUnavailable|http:NotFound|http:InternalServerError {
        byte[] correlationId = uuid:createType1AsString().toBytes();
        ibmmq:Message message = mapToPaymentInstructionMessage(paymentInstruction, correlationId);

        ibmmq:Error? putResult = paymentInstructionsQueue->put(message);
        if putResult is ibmmq:Error {
            return mapToHttpError(putResult);
        }

        string correlationKey = correlationId.toBase16();
        lock {
            pendingPaymentInstructions[correlationKey] = paymentInstruction.instructionId;
        }

        return <http:Accepted>{body: {instructionId: paymentInstruction.instructionId}};
    }
}

@ibmmq:ServiceConfig {
    queueName: paymentResponsesQueueName,
    sessionAckMode: ibmmq:CLIENT_ACKNOWLEDGE
}
service ibmmq:Service on paymentResponsesListener {

    # Handles an incoming payment response message, correlating it to a
    # pending payment instruction before acknowledging it through the caller.
    #
    # + message - the received IBM MQ message
    # + caller - the caller used to acknowledge the message
    # + return - an error if the message could not be processed
    remote function onMessage(ibmmq:Message message, ibmmq:Caller caller) returns error? {
        byte[]? correlationIdBytes = message.correlationId;
        if correlationIdBytes is () {
            log:printWarn("Received a payment response without a correlation ID");
            return;
        }

        string correlationKey = correlationIdBytes.toBase16();
        string? instructionId = ();
        lock {
            if pendingPaymentInstructions.hasKey(correlationKey) {
                instructionId = pendingPaymentInstructions.remove(correlationKey);
            }
        }

        if instructionId is () {
            log:printWarn("Received a payment response that does not match any pending payment instruction",
                    correlationId = correlationKey);
            return;
        }

        PaymentResponse|error paymentResponse = mapToPaymentResponse(message, instructionId);
        if paymentResponse is error {
            log:printError("Failed to map the payment response message", paymentResponse,
                    instructionId = instructionId);
            return;
        }

        ibmmq:Error? acknowledgeResult = caller->acknowledge(message);
        if acknowledgeResult is ibmmq:Error {
            log:printError("Failed to acknowledge the payment response message", acknowledgeResult,
                    instructionId = instructionId);
            return;
        }

        log:printInfo("Processed payment response", instructionId = instructionId,
                status = paymentResponse.status, timestamp = time:utcToString(time:utcNow()));
    }

    # Handles runtime errors that occur while receiving or dispatching
    # messages from PAYMENT.RESPONSES.
    #
    # + mqError - the error encountered by the listener
    remote function onError(ibmmq:Error mqError) returns error? {
        log:printError("Error while receiving payment response from IBM MQ", mqError);
    }
}
