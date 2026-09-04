import ballerina/lang.runtime;
import ballerina/log;
import ballerina/time;
import ballerinax/asb;

// Returns the current UTC timestamp in ISO 8601 format.
function getCurrentTimestamp() returns string {
    return time:utcToString(time:utcNow());
}

// Provisions the claims-intake queue if it does not already exist, configured with
// duplicate detection, dead-lettering on message expiration, a configurable TTL, lock
// duration, and maximum delivery count.
function provisionClaimsIntakeQueue() returns error? {
    boolean|asb:Error? queueExists = asbAdmin->queueExists(claimsIntakeQueue);
    if queueExists is asb:Error {
        return queueExists;
    }

    boolean queueAlreadyExists = queueExists is boolean && queueExists;
    if queueAlreadyExists {
        log:printInfo("Claims-intake queue already exists", queueName = claimsIntakeQueue);
        return;
    }

    asb:CreateQueueOptions queueOptions = {
        defaultMessageTimeToLive: {seconds: claimMessageTimeToLiveSeconds},
        lockDuration: {seconds: claimLockDurationSeconds},
        maxDeliveryCount: claimMaxDeliveryCount,
        duplicateDetectionHistoryTimeWindow: {seconds: duplicateDetectionWindowSeconds},
        requiresDuplicateDetection: true,
        deadLetteringOnMessageExpiration: true
    };
    asb:QueueProperties|asb:Error? createdQueue = asbAdmin->createQueue(claimsIntakeQueue, queueOptions = queueOptions);
    if createdQueue is asb:Error {
        return createdQueue;
    }
    log:printInfo("Created claims-intake queue", queueName = claimsIntakeQueue);
}

// Submits a batch of claim submissions to the claims-intake queue using sendBatch. Each
// claim is set as an individual message with its claimId used as both the message id
// (for duplicate detection) and the correlation id.
function submitClaimBatch(ClaimSubmission[] claims) returns error? {
    asb:Message[] claimMessages = from ClaimSubmission claim in claims
        select {
            body: claim.toJson().toJsonString().toBytes(),
            contentType: "application/json",
            messageId: claim.claimId,
            correlationId: claim.claimId
        };

    asb:MessageBatch messageBatch = {
        messageCount: claimMessages.length(),
        messages: claimMessages
    };
    check claimsIntakeSender->sendBatch(messageBatch);
    log:printInfo("Submitted claim batch to claims-intake queue", claimCount = claimMessages.length());
}

// Parses the raw message body received from the claims-intake queue into a ClaimSubmission.
function parseClaimSubmission(anydata messageBody) returns ClaimSubmission|error {
    if messageBody is byte[] {
        string jsonText = check string:fromBytes(messageBody);
        json claimJson = check jsonText.fromJsonString();
        return claimJson.cloneWithType(ClaimSubmission);
    }
    return messageBody.cloneWithType(ClaimSubmission);
}

// Validates a ClaimSubmission's policy and amount fields, among other required fields.
// Returns an error describing the first validation failure found, or () when the claim
// is valid. Validation failures are treated as permanent and are dead-lettered.
function validateClaimSubmission(ClaimSubmission claim) returns error? {
    if claim.claimId.trim().length() == 0 {
        return error("claimId must not be empty");
    }
    if claim.policyNumber.trim().length() == 0 {
        return error("policyNumber must not be empty");
    }
    if claim.claimantId.trim().length() == 0 {
        return error("claimantId must not be empty");
    }
    if claim.claimAmount <= 0d {
        return error("claimAmount must be greater than zero");
    }
    if claim.incidentDate.trim().length() == 0 {
        return error("incidentDate must not be empty");
    }
    return;
}

// Scores a validated claim to produce an assessment decision. This simulates a scoring
// engine call that may fail transiently (e.g. a downstream scoring service outage),
// in which case the caller should abandon the message so it can be retried. When the
// claim carries a simulatedProcessingDelaySeconds value, scoring is artificially
// delayed by that many seconds to exercise assessments that outlast the queue's lock
// duration.
function scoreClaim(ClaimSubmission claim) returns ClaimAssessmentResult|error {
    int? simulatedProcessingDelaySeconds = claim.simulatedProcessingDelaySeconds;
    if simulatedProcessingDelaySeconds is int && simulatedProcessingDelaySeconds > 0 {
        runtime:sleep(<decimal>simulatedProcessingDelaySeconds);
    }

    string decision = claim.claimAmount > 50000d ? "MANUAL_REVIEW" : "APPROVED";
    ClaimAssessmentResult result = {
        claimId: claim.claimId,
        policyNumber: claim.policyNumber,
        decision: decision,
        assessedAmount: claim.claimAmount,
        reason: string `Claim ${claim.claimId} assessed with decision ${decision}`,
        assessedAt: getCurrentTimestamp()
    };
    return result;
}

// Publishes a claim assessment result back to the claims-intake queue's originating
// flow by logging and returning success; in a full deployment this would send the
// result to a downstream assessment-results entity.
function publishAssessmentResult(ClaimAssessmentResult result) returns error? {
    log:printInfo("Published claim assessment result", claimId = result.claimId, decision = result.decision);
}

// Increments the completed settlement counter.
function recordCompleted() {
    lock {
        operationalCounters.completedCount += 1;
    }
}

// Increments the dead-lettered settlement counter.
function recordDeadLettered() {
    lock {
        operationalCounters.deadLetteredCount += 1;
    }
}

// Increments the abandoned settlement counter.
function recordAbandoned() {
    lock {
        operationalCounters.abandonedCount += 1;
    }
}

// Increments the lock-renewal failure counter.
function recordLockRenewalFailed() {
    lock {
        operationalCounters.lockRenewalFailedCount += 1;
    }
}

// Returns a snapshot copy of the current operational counters.
function getOperationalCounters() returns OperationalCounters {
    lock {
        return operationalCounters.clone();
    }
}
