import ballerina/http;
import ballerina/lang.runtime;
import ballerina/test;

final http:Client testClaimsClient = check new (string `http://localhost:${httpPort}/claims`);

// Polls the health endpoint until the given counter increases beyond its baseline value,
// or the retry budget is exhausted.
function waitForCounterIncrease(string counterName, int baselineValue, int maxAttempts = 40) returns OperationalCounters|error {
    int attempt = 0;
    while attempt < maxAttempts {
        OperationalCounters counters = check testClaimsClient->/health.get();
        int currentValue = counterName == "completed" ? counters.completedCount :
            counterName == "deadLettered" ? counters.deadLetteredCount : counters.abandonedCount;
        if currentValue > baselineValue {
            return counters;
        }
        runtime:sleep(1);
        attempt += 1;
    }
    return error("Timed out waiting for " + counterName + " counter to increase");
}

// Generates a unique claim id per test invocation so that duplicate detection on the
// claims-intake queue does not interfere between test runs.
function uniqueClaimId(string prefix) returns string {
    return prefix + "-" + getCurrentTimestamp();
}

@test:Config {}
function testSubmitClaimBatchAccepted() returns error? {
    ClaimSubmissionBatch batch = {
        claims: [
            {
                claimId: uniqueClaimId("CLM-BATCH-1"),
                policyNumber: "POL-1001",
                claimantId: "CUST-1",
                claimAmount: 1500.00d,
                incidentDate: "2026-08-01"
            },
            {
                claimId: uniqueClaimId("CLM-BATCH-2"),
                policyNumber: "POL-1002",
                claimantId: "CUST-2",
                claimAmount: 2500.00d,
                incidentDate: "2026-08-02"
            }
        ]
    };

    http:Response response = check testClaimsClient->/batchSubmissions.post(batch);

    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Unexpected status code in response");

    json responseBody = check response.getJsonPayload();
    ClaimBatchAccepted acceptedBody = check responseBody.cloneWithType(ClaimBatchAccepted);

    test:assertEquals(acceptedBody.claimCount, 2, msg = "Unexpected claimCount in response");
    test:assertEquals(acceptedBody.message, "Claim batch submitted", msg = "Unexpected message in response");
}

@test:Config {}
function testParseClaimSubmissionFromBytes() returns error? {
    ClaimSubmission originalClaim = {
        claimId: "CLM-PARSE-1",
        policyNumber: "POL-2002",
        claimantId: "CUST-9",
        claimAmount: 3200.50d,
        incidentDate: "2026-08-05"
    };

    byte[] serializedClaim = originalClaim.toJson().toJsonString().toBytes();
    ClaimSubmission parsedClaim = check parseClaimSubmission(serializedClaim);

    test:assertEquals(parsedClaim, originalClaim, msg = "Parsed claim does not match the original claim");
}

@test:Config {}
function testValidateClaimSubmissionAcceptsValidClaim() returns error? {
    ClaimSubmission validClaim = {
        claimId: "CLM-VALID-1",
        policyNumber: "POL-3001",
        claimantId: "CUST-3",
        claimAmount: 999.99d,
        incidentDate: "2026-08-06"
    };

    error? validationResult = validateClaimSubmission(validClaim);
    test:assertTrue(validationResult is (), msg = "Expected a valid claim to pass validation");
}

@test:Config {}
function testValidateClaimSubmissionRejectsInvalidPolicyAndAmount() returns error? {
    ClaimSubmission invalidClaim = {
        claimId: "CLM-INVALID-1",
        policyNumber: "",
        claimantId: "CUST-4",
        claimAmount: 0d,
        incidentDate: "2026-08-07"
    };

    error? validationResult = validateClaimSubmission(invalidClaim);
    test:assertTrue(validationResult is error, msg = "Expected an invalid claim to fail validation");
}

// Settlement path: valid claim -> assessment scored -> result published -> message completed.
@test:Config {}
function testValidClaimIsCompletedAfterAssessmentPublication() returns error? {
    OperationalCounters baselineCounters = check testClaimsClient->/health.get();

    ClaimSubmissionBatch batch = {
        claims: [
            {
                claimId: uniqueClaimId("CLM-COMPLETE"),
                policyNumber: "POL-COMPLETE",
                claimantId: "CUST-COMPLETE",
                claimAmount: 4200.00d,
                incidentDate: "2026-08-08"
            }
        ]
    };

    http:Response response = check testClaimsClient->/batchSubmissions.post(batch);
    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Expected the claim batch submission to be accepted");

    OperationalCounters updatedCounters = check waitForCounterIncrease("completed", baselineCounters.completedCount);
    test:assertTrue(updatedCounters.completedCount > baselineCounters.completedCount, msg = "Expected completedCount to increase after assessment publication");
}

// Settlement path: permanent validation failure (invalid policy/amount) -> claim dead-lettered with a reason.
@test:Config {}
function testInvalidClaimIsDeadLettered() returns error? {
    OperationalCounters baselineCounters = check testClaimsClient->/health.get();

    ClaimSubmissionBatch batch = {
        claims: [
            {
                claimId: uniqueClaimId("CLM-DEADLETTER"),
                policyNumber: "",
                claimantId: "CUST-DEADLETTER",
                claimAmount: -10.00d,
                incidentDate: "2026-08-09"
            }
        ]
    };

    http:Response response = check testClaimsClient->/batchSubmissions.post(batch);
    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Expected the claim batch submission to be accepted by the queue");

    OperationalCounters updatedCounters = check waitForCounterIncrease("deadLettered", baselineCounters.deadLetteredCount);
    test:assertTrue(updatedCounters.deadLetteredCount > baselineCounters.deadLetteredCount, msg = "Expected deadLetteredCount to increase after validation failure");
}

// Scoring path: scoreClaim produces a decision for a valid claim without error.
@test:Config {}
function testScoreClaimProducesAssessmentResult() returns error? {
    ClaimSubmission claim = {
        claimId: "CLM-SCORE-1",
        policyNumber: "POL-SCORE-1",
        claimantId: "CUST-SCORE",
        claimAmount: 75000.00d,
        incidentDate: "2026-08-10"
    };

    ClaimAssessmentResult result = check scoreClaim(claim);
    test:assertEquals(result.claimId, "CLM-SCORE-1", msg = "Unexpected claimId in assessment result");
    test:assertEquals(result.decision, "MANUAL_REVIEW", msg = "Expected a high-value claim to require manual review");
}

// Lock-renewal path: an assessment that runs longer than the queue's configured lock
// duration must still complete successfully, because the worker keeps renewing the
// claim message's lock in the background while scoring is in progress. The
// lockRenewalFailedCount should remain unchanged since lock renewal is expected to
// succeed throughout.
//
// This test intentionally holds up the single claim-assessment worker loop for longer
// than the lock duration. It depends on the other settlement-path tests so that it
// always runs last, and therefore never head-of-line-blocks their tighter
// waitForCounterIncrease budgets.
@test:Config {
    dependsOn: [
        testSubmitClaimBatchAccepted,
        testValidClaimIsCompletedAfterAssessmentPublication,
        testInvalidClaimIsDeadLettered
    ]
}
function testSlowAssessmentIsCompletedAfterLockRenewal() returns error? {
    OperationalCounters baselineCounters = check testClaimsClient->/health.get();

    int slowProcessingDelaySeconds = claimLockDurationSeconds + 15;

    ClaimSubmissionBatch batch = {
        claims: [
            {
                claimId: uniqueClaimId("CLM-SLOW"),
                policyNumber: "POL-SLOW",
                claimantId: "CUST-SLOW",
                claimAmount: 3300.00d,
                incidentDate: "2026-08-11",
                simulatedProcessingDelaySeconds: slowProcessingDelaySeconds
            }
        ]
    };

    http:Response response = check testClaimsClient->/batchSubmissions.post(batch);
    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Expected the claim batch submission to be accepted");

    OperationalCounters updatedCounters = check waitForCounterIncrease("completed", baselineCounters.completedCount, maxAttempts = slowProcessingDelaySeconds + 30);
    test:assertTrue(updatedCounters.completedCount > baselineCounters.completedCount, msg = "Expected completedCount to increase once the slow assessment completes");
    test:assertEquals(updatedCounters.lockRenewalFailedCount, baselineCounters.lockRenewalFailedCount, msg = "Expected no lock-renewal failures for a healthy renewal loop");
}
