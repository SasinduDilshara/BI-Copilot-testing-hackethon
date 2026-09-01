import ballerina/log;
import ballerina/time;

// Processes a received claim submission. Any business validation or
// downstream processing failures are returned as an error so the caller can
// roll back the transaction.
function processClaimSubmission(ClaimSubmission claimSubmission) returns error? {
    if claimSubmission.claimAmount <= 0d {
        return error("Claim amount must be greater than zero", claimId = claimSubmission.claimId);
    }
    log:printInfo("Processed claim submission", claimId = claimSubmission.claimId,
            policyNumber = claimSubmission.policyNumber);
}

// Writes an audit entry for a processed claim submission. A failure here
// must also cause the transaction to be rolled back so the claim is
// redelivered.
function writeAuditEntry(ClaimSubmission claimSubmission) returns error? {
    AuditEntry auditEntry = {
        claimId: claimSubmission.claimId,
        status: "PROCESSED",
        processedAt: time:utcToString(time:utcNow())
    };
    log:printInfo("Audit entry written", claimId = auditEntry.claimId,
            status = auditEntry.status, processedAt = auditEntry.processedAt);
}
