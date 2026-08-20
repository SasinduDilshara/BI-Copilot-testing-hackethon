import ballerina/lang.runtime;
import ballerina/log;
import ballerina/sql;
import ballerinax/oracledb;

# Determines whether the given error is a transient connection error that is safe to retry.
#
# + dbError - the error returned from a database operation
# + return - true if the error looks like a transient connection issue
function isTransientConnectionError(error dbError) returns boolean {
    if dbError is sql:DatabaseError {
        sql:DatabaseErrorDetail detail = dbError.detail();
        int sqlErrorCode = detail.errorCode;
        // Common Oracle transient connection related error codes.
        int[] transientCodes = [12541, 12514, 12170, 3113, 3114, 12537, 12528, 12520, 1033, 1034, 1089];
        return transientCodes.indexOf(sqlErrorCode) is int;
    }
    return false;
}

# Calls the Oracle PL/SQL stored procedure CALCULATE_PREMIUM (with an OUT parameter for the
# result) and maps the returned PREMIUM_BREAKDOWN_TYPE OBJECT into a PremiumBreakdown record.
#
# + dbClient - the database client to use for the call, in scope of the active transaction
# + policyId - the policy identifier
# + coverageAmount - the coverage amount of the policy
# + riskTier - the risk tier of the policy
# + return - the mapped PremiumBreakdown record, or an sql:Error
function calculatePremium(oracledb:Client dbClient, string policyId, decimal coverageAmount, RiskTier riskTier)
        returns PremiumBreakdown|error {
    oracledb:ObjectOutParameter premiumBreakdownOut = new (typeName = "PREMIUM_BREAKDOWN_TYPE");
    sql:ProcedureCallResult callResult = check dbClient->call(
        `call CALCULATE_PREMIUM(${policyId}, ${coverageAmount}, ${riskTier}, ${premiumBreakdownOut})`
    );
    check callResult.close();
    PremiumBreakdown premiumBreakdown = check premiumBreakdownOut.get(PremiumBreakdown);
    return premiumBreakdown;
}

# Executes the bind operation (premium calculation plus the two inserts) within a single
# database transaction. Rolls back both inserts if either one fails.
#
# + bindRequest - the incoming policy bind request
# + return - the response to return to the caller, or an error on failure
function bindPolicyInTransaction(PolicyBindRequest bindRequest) returns PolicyBoundResponse|error {
    string policyId = bindRequest.policyId;
    string customerId = bindRequest.customerId;
    decimal coverageAmount = bindRequest.coverageAmount;
    RiskTier riskTier = bindRequest.riskTier;

    PolicyBoundResponse|error result = trap calculateAndPersist(policyId, customerId, coverageAmount, riskTier);
    return result;
}

function calculateAndPersist(string policyId, string customerId, decimal coverageAmount, RiskTier riskTier)
        returns PolicyBoundResponse|error {
    PolicyBoundResponse boundResponse;
    transaction {
        PremiumBreakdown premiumBreakdown = check calculatePremium(policyDbClient, policyId, coverageAmount, riskTier);
        decimal totalPremium = premiumBreakdown.baseAmount + premiumBreakdown.taxAmount + premiumBreakdown.brokerFee;

        sql:ParameterizedQuery insertPolicyQuery = `INSERT INTO policies
            (policy_id, customer_id, coverage_amount, risk_tier, total_premium)
            VALUES (${policyId}, ${customerId}, ${coverageAmount}, ${riskTier}, ${totalPremium})`;
        _ = check policyDbClient->execute(insertPolicyQuery);

        sql:ParameterizedQuery insertLedgerQuery = `INSERT INTO ledger_entries
            (policy_id, customer_id, base_amount, tax_amount, broker_fee, total_premium)
            VALUES (${policyId}, ${customerId}, ${premiumBreakdown.baseAmount}, ${premiumBreakdown.taxAmount},
                    ${premiumBreakdown.brokerFee}, ${totalPremium})`;
        _ = check policyDbClient->execute(insertLedgerQuery);

        boundResponse = {
            policyId,
            customerId,
            totalPremium,
            premiumBreakdown
        };
        check commit;
    }
    return boundResponse;
}

# Attempts to bind the policy, retrying up to the configured number of attempts with
# exponential backoff when a transient connection error occurs.
#
# + bindRequest - the incoming policy bind request
# + return - the successful bind response, or the last encountered error if all retries were exhausted
function bindPolicyWithRetry(PolicyBindRequest bindRequest) returns PolicyBoundResponse|error {
    error lastError = error("bind operation did not execute");
    int attempt = 0;
    while attempt < maxRetryAttempts {
        attempt += 1;
        PolicyBoundResponse|error bindResult = bindPolicyInTransaction(bindRequest);
        if bindResult is PolicyBoundResponse {
            return bindResult;
        }
        lastError = bindResult;
        boolean transientError = isTransientConnectionError(bindResult);
        if !transientError || attempt >= maxRetryAttempts {
            break;
        }
        decimal backoffSeconds = retryBaseDelaySeconds * (2 ^ (attempt - 1));
        log:printWarn("Transient error while binding policy, retrying",
                policyId = bindRequest.policyId, attempt = attempt, backoffSeconds = backoffSeconds,
                'error = lastError);
        runtime:sleep(backoffSeconds);
    }
    return lastError;
}

# Writes the original request payload and the failure reason into the policies_dlq table
# so that the application is not lost after retries are exhausted.
#
# + bindRequest - the original policy bind request
# + failureReason - the reason the bind operation ultimately failed
# + return - an sql:Error if the DLQ insert itself fails
function writeToDeadLetterQueue(PolicyBindRequest bindRequest, string failureReason) returns error? {
    json requestPayload = bindRequest.toJson();
    string requestPayloadText = requestPayload.toJsonString();
    sql:ParameterizedQuery insertDlqQuery = `INSERT INTO policies_dlq
        (policy_id, customer_id, request_payload, error_reason)
        VALUES (${bindRequest.policyId}, ${bindRequest.customerId}, ${requestPayloadText}, ${failureReason})`;
    sql:ExecutionResult|error executeResult = policyDbClient->execute(insertDlqQuery);
    if executeResult is error {
        log:printError("Failed to write policy bind failure to the dead letter queue",
                policyId = bindRequest.policyId, 'error = executeResult);
        return executeResult;
    }
}
