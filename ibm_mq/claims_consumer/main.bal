import ballerina/log;
import ballerinax/ibm.ibmmq;

@ibmmq:ServiceConfig {
    queueName: claimsInboundQueueName,
    sessionAckMode: ibmmq:CLIENT_ACKNOWLEDGE
}
service ibmmq:Service on claimsInboundListener {

    # Handles an incoming claim submission message under client
    # acknowledgement. Messages that have exceeded the maximum delivery
    # attempts are treated as poison messages: they are routed to
    # CLAIMS.DLQ with the failure reason and attempt count as properties,
    # and then acknowledged so the claim leaves the input queue. Otherwise,
    # the message is acknowledged only after the claim has been processed
    # and the audit entry has been appended to the audit log; if either
    # step fails, the message is left unacknowledged so it is redelivered.
    #
    # + message - the received IBM MQ message
    # + caller - the caller used to acknowledge the message
    # + return - an error if the acknowledgement itself fails
    remote function onMessage(ibmmq:Message message, ibmmq:Caller caller) returns error? {
        int deliveryCount = recordDeliveryAttempt(message);

        ClaimSubmission|error claimSubmission = mapToClaimSubmission(message);
        if claimSubmission is error {
            return handleFailedClaim(message, deliveryCount, "Failed to bind the claim submission payload: "
                    + claimSubmission.message(), caller);
        }

        error? processResult = processClaimSubmission(claimSubmission);
        if processResult is error {
            return handleFailedClaim(message, deliveryCount, "Failed to process the claim submission: "
                    + processResult.message(), caller);
        }

        error? auditResult = writeAuditEntry(claimSubmission);
        if auditResult is error {
            return handleFailedClaim(message, deliveryCount, "Failed to write the audit entry: "
                    + auditResult.message(), caller);
        }

        ibmmq:Error? acknowledgeResult = caller->acknowledge(message);
        if acknowledgeResult is ibmmq:Error {
            log:printError("Failed to acknowledge the claim submission", acknowledgeResult,
                    claimId = claimSubmission.claimId);
            return acknowledgeResult;
        }

        clearDeliveryAttempts(message);
        log:printInfo("Claim submission acknowledged", claimId = claimSubmission.claimId);
    }

    # Handles runtime errors that occur while receiving or dispatching
    # messages from CLAIMS.INBOUND.
    #
    # + mqError - the error encountered by the listener
    remote function onError(ibmmq:Error mqError) returns error? {
        log:printError("Error while receiving claim submission from IBM MQ", mqError);
    }
}

// Handles a claim that failed to be processed. Once the delivery count
// exceeds the configured maximum, the claim is considered a poison message:
// it is put on CLAIMS.DLQ with the failure reason and attempt count as
// properties, and then acknowledged so it leaves CLAIMS.INBOUND. Otherwise,
// the message is left unacknowledged so it is redelivered.
function handleFailedClaim(ibmmq:Message originalMessage, int deliveryCount, string failureReason,
        ibmmq:Caller caller) returns error? {
    log:printError(failureReason, deliveryCount = deliveryCount);

    if deliveryCount > maxDeliveryAttempts {
        ibmmq:Message deadLetterMessage = mapToDeadLetterMessage(originalMessage, failureReason, deliveryCount);
        ibmmq:Error? putResult = claimsDlq->put(deadLetterMessage);
        if putResult is ibmmq:Error {
            log:printError("Failed to put the claim on CLAIMS.DLQ", putResult);
            return;
        }

        ibmmq:Error? acknowledgeResult = caller->acknowledge(originalMessage);
        if acknowledgeResult is ibmmq:Error {
            log:printError("Failed to acknowledge the claim after routing it to CLAIMS.DLQ", acknowledgeResult);
            return acknowledgeResult;
        }

        clearDeliveryAttempts(originalMessage);
        log:printWarn("Claim routed to CLAIMS.DLQ after exceeding the maximum delivery attempts",
                deliveryCount = deliveryCount, failureReason = failureReason);
        return;
    }
}
