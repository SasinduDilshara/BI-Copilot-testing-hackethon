import ballerina/lang.runtime;
import ballerina/log;
import ballerinax/asb;

boolean workerShouldRun = true;

// Signals a background lock-renewal task to stop once the processing it is guarding
// has finished.
isolated class RenewalSignal {
    private boolean stopRequested = false;

    isolated function requestStop() {
        lock {
            self.stopRequested = true;
        }
    }

    isolated function shouldStop() returns boolean {
        lock {
            return self.stopRequested;
        }
    }
}

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

    ClaimAssessmentResult|error assessmentResult = assessClaimWithLockRenewal(claimMessage, claim);
    if assessmentResult is error {
        log:printError("Transient failure while assessing or publishing claim result; abandoning message for retry", assessmentResult, claimId = claim.claimId);
        asb:Error? abandonResult = claimsIntakeReceiver->abandon(claimMessage);
        if abandonResult is asb:Error {
            log:printError("Failed to abandon claim message", abandonResult, claimId = claim.claimId);
            return abandonResult;
        }
        recordAbandoned();
        return;
    }

    if assessmentResult.decision == "MANUAL_REVIEW" {
        return deferClaimForManualReview(claimMessage, assessmentResult);
    }

    asb:Error? completeResult = claimsIntakeReceiver->complete(claimMessage);
    if completeResult is asb:Error {
        log:printError("Failed to complete claim message after publishing assessment result", completeResult, claimId = claim.claimId);
        return completeResult;
    }
    recordCompleted();
}

// Defers a claim message that has been marked for manual review instead of completing
// or abandoning it, storing its Service Bus sequence number so it can be retrieved
// later via the deferred-claims endpoint.
function deferClaimForManualReview(asb:Message claimMessage, ClaimAssessmentResult assessmentResult) returns error? {
    int|asb:Error deferResult = claimsIntakeReceiver->defer(claimMessage);
    if deferResult is asb:Error {
        log:printError("Failed to defer claim message for manual review", deferResult, claimId = assessmentResult.claimId);
        return deferResult;
    }

    int sequenceNumber = deferResult;
    DeferredClaim deferredClaim = {
        sequenceNumber: sequenceNumber,
        claimId: assessmentResult.claimId,
        policyNumber: assessmentResult.policyNumber,
        claimAmount: assessmentResult.assessedAmount,
        deferredAt: getCurrentTimestamp()
    };
    recordDeferredClaim(deferredClaim);
    recordDeferred();
    log:printInfo("Deferred claim for manual review", claimId = assessmentResult.claimId, sequenceNumber = sequenceNumber);
}

// Scores the claim and publishes the assessment result while periodically renewing the
// claim message's lock in the background, since assessment can take longer than the
// claims-intake queue's configured lock duration. Returns the assessment result, or an
// error if scoring or publishing failed transiently.
function assessClaimWithLockRenewal(asb:Message claimMessage, ClaimSubmission claim) returns ClaimAssessmentResult|error {
    RenewalSignal renewalSignal = new;
    future<()> renewalTask = start renewMessageLockPeriodically(claimMessage, renewalSignal);

    ClaimAssessmentResult|error assessmentResult = scoreClaim(claim);
    error? publishResult = ();
    if assessmentResult is ClaimAssessmentResult {
        publishResult = publishAssessmentResult(assessmentResult);
    }

    renewalSignal.requestStop();
    error? renewalTaskResult = wait renewalTask;
    if renewalTaskResult is error {
        log:printError("Lock-renewal background task terminated unexpectedly", renewalTaskResult, claimId = claim.claimId);
    }

    if assessmentResult is error {
        return assessmentResult;
    }
    if publishResult is error {
        return publishResult;
    }
    return assessmentResult;
}

// Periodically renews the lock on a claim message while it is being processed. Stops
// once the given RenewalSignal is signalled to stop. Each renewal failure is recorded
// in the operational counters so it is visible in health metrics.
function renewMessageLockPeriodically(asb:Message claimMessage, RenewalSignal renewalSignal) {
    while !renewalSignal.shouldStop() {
        runtime:sleep(lockRenewalIntervalSeconds);
        if renewalSignal.shouldStop() {
            break;
        }

        asb:Error? renewResult = claimsIntakeReceiver->renewLock(claimMessage);
        if renewResult is asb:Error {
            string? correlationId = claimMessage.correlationId;
            string claimIdForLog = correlationId ?: "unknown";
            log:printError("Failed to renew lock on claim message", renewResult, claimId = claimIdForLog);
            recordLockRenewalFailed();
        }
    }
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
