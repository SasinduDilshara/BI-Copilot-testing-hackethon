import ballerina/log;
import ballerinax/asb;

boolean workerShouldRun = true;

function init() returns error? {
    check provisionClaimsIntakeQueue();
    // Runs the claim-assessment batch worker loop in the background so the HTTP
    // intake endpoint can start serving requests immediately.
    _ = @strand {thread: "any"} start runClaimAssessmentWorker();
}

// Continuously receives batches of claim submissions from the claims-intake queue in
// PEEK_LOCK mode and assesses each claim in the batch.
function runClaimAssessmentWorker() returns error? {
    while workerShouldRun {
        asb:MessageBatch|asb:Error? receiveResult = claimsIntakeReceiver->receiveBatch(receiveBatchSize, receiveServerWaitTimeSeconds);
        if receiveResult is asb:Error {
            log:printError("Error occurred while receiving a batch of claim messages from ASB", receiveResult);
            continue;
        }
        if receiveResult is () {
            continue;
        }

        asb:MessageBatch claimMessageBatch = receiveResult;
        asb:Message[]? claimMessages = claimMessageBatch.messages;
        if claimMessages is () {
            continue;
        }

        foreach asb:Message claimMessage in claimMessages {
            check processClaimMessage(claimMessage);
        }
    }
}

// Processes a single claim message retrieved from the claims-intake queue: parses and
// validates the claim, scores it, publishes the assessment result, and settles the
// message accordingly.
function processClaimMessage(asb:Message claimMessage) returns error? {
    anydata messageBody = claimMessage.body;
    ClaimSubmission|error claim = parseClaimSubmission(messageBody);
    if claim is error {
        log:printError("Failed to bind message body to ClaimSubmission", claim);
        check deadLetterClaim(claimMessage, "InvalidClaim", "Message body could not be parsed into a ClaimSubmission: " + claim.message());
        return;
    }

    error? validationResult = validateClaimSubmission(claim);
    if validationResult is error {
        log:printError("Claim submission failed validation", validationResult, claimId = claim.claimId);
        check deadLetterClaim(claimMessage, "ValidationFailed", validationResult.message());
        return;
    }

    log:printInfo("Received claim submission", claimId = claim.claimId, policyNumber = claim.policyNumber);

    ClaimAssessmentResult|error assessmentResult = scoreClaim(claim);
    if assessmentResult is error {
        log:printError("Transient scoring failure; abandoning message for retry", assessmentResult, claimId = claim.claimId);
        asb:Error? abandonResult = claimsIntakeReceiver->abandon(claimMessage);
        if abandonResult is asb:Error {
            log:printError("Failed to abandon claim message", abandonResult, claimId = claim.claimId);
            return abandonResult;
        }
        recordAbandoned();
        return;
    }

    error? publishResult = publishAssessmentResult(assessmentResult);
    if publishResult is error {
        log:printError("Failed to publish claim assessment result; abandoning message for retry", publishResult, claimId = claim.claimId);
        asb:Error? abandonResult = claimsIntakeReceiver->abandon(claimMessage);
        if abandonResult is asb:Error {
            log:printError("Failed to abandon claim message", abandonResult, claimId = claim.claimId);
            return abandonResult;
        }
        recordAbandoned();
        return;
    }

    asb:Error? completeResult = claimsIntakeReceiver->complete(claimMessage);
    if completeResult is asb:Error {
        log:printError("Failed to complete claim message after publishing assessment result", completeResult, claimId = claim.claimId);
        return completeResult;
    }
    recordCompleted();
}

// Dead-letters a claim message with the given reason and description, recording the
// outcome in the operational counters.
function deadLetterClaim(asb:Message claimMessage, string deadLetterReason, string deadLetterErrorDescription) returns error? {
    asb:Error? deadLetterResult = claimsIntakeReceiver->deadLetter(claimMessage, deadLetterReason = deadLetterReason, deadLetterErrorDescription = deadLetterErrorDescription);
    if deadLetterResult is asb:Error {
        log:printError("Failed to dead-letter claim message", deadLetterResult, deadLetterReason = deadLetterReason);
        return deadLetterResult;
    }
    recordDeadLettered();
}
