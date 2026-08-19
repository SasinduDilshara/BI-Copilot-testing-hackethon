import ballerina/http;
import ballerina/lang.runtime;
import ballerina/sql;

const int MAX_RETRIES = 4;
const decimal BASE_BACKOFF_SECONDS = 0.3;

function getActivePolicyholder(string policyNumber) returns Policyholder|sql:Error {
    sql:ParameterizedQuery query = `SELECT policy_number AS policyNumber, coverage_limit AS coverageLimit,
        is_active AS isActive FROM policyholders WHERE policy_number = ${policyNumber}`;
    return claimsDbClient->queryRow(query);
}

function insertClaim(ClaimSubmission claim, decimal coverageLimit) returns sql:ExecutionResult|sql:Error {
    sql:ParameterizedQuery query = `INSERT INTO claims (claim_number, policy_number, provider_id, diagnosis_code,
        billed_amount, service_date, coverage_limit) VALUES (${claim.claimNumber}, ${claim.policyNumber},
        ${claim.providerId}, ${claim.diagnosisCode}, ${claim.billedAmount}, ${claim.serviceDate}, ${coverageLimit})`;
    return claimsDbClient->execute(query);
}

function insertDeadLetterClaim(ClaimSubmission claim, string reason) returns sql:Error? {
    sql:ParameterizedQuery query = `INSERT INTO dead_letter_claims (claim_number, policy_number, claim_payload,
        error_reason) VALUES (${claim.claimNumber}, ${claim.policyNumber}, ${claim.toJsonString()}, ${reason})`;
    sql:ExecutionResult|sql:Error result = claimsDbClient->execute(query);
    if result is sql:Error {
        return result;
    }
    return;
}

function callAdjudication(AdjudicationRequest req) returns error? {
    http:Response _ = check adjudicationClient->post("/adjudicate", req,
        {"Authorization": "Bearer " + adjudicationApiKey});
}

function processClaimWithRetry(ClaimSubmission claim, decimal coverageLimit) returns error? {
    AdjudicationRequest req = {
        claimNumber: claim.claimNumber,
        policyNumber: claim.policyNumber,
        diagnosisCode: claim.diagnosisCode,
        billedAmount: claim.billedAmount,
        coverageLimit: coverageLimit
    };

    int attempt = 0;
    while true {
        sql:ExecutionResult|sql:Error insertResult = insertClaim(claim, coverageLimit);
        if insertResult is sql:DatabaseError {
            check insertDeadLetterClaim(claim, "Duplicate claim number or database constraint violation: " + insertResult.message());
            return;
        }

        error? attemptError = ();
        if insertResult is sql:Error {
            attemptError = insertResult;
        } else {
            error? adjudicationResult = callAdjudication(req);
            if adjudicationResult is error {
                attemptError = adjudicationResult;
            }
        }

        if attemptError is () {
            return;
        }

        attempt += 1;
        if attempt >= MAX_RETRIES {
            check insertDeadLetterClaim(claim, attemptError.message());
            return;
        }

        decimal backoffSeconds = BASE_BACKOFF_SECONDS * (2 ^ (attempt - 1));
        runtime:sleep(backoffSeconds);
    }
}
