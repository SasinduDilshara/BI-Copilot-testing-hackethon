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

# Calls the read-only premium calculation, retrying up to the configured number of attempts
# with exponential backoff when a transient connection error occurs. This is safe to retry
# since it does not mutate any state.
#
# + bindRequest - the incoming policy bind request
# + return - the calculated PremiumBreakdown, or the last encountered error if all retries were exhausted
function calculatePremiumWithRetry(PolicyBindRequest bindRequest) returns PremiumBreakdown|error {
    string policyId = bindRequest.policyId;
    decimal coverageAmount = bindRequest.coverageAmount;
    RiskTier riskTier = bindRequest.riskTier;

    error lastError = error("premium calculation did not execute");
    int attempt = 0;
    while attempt < maxRetryAttempts {
        attempt += 1;
        PremiumBreakdown|error calculationResult = calculatePremium(policyDbClient, policyId, coverageAmount, riskTier);
        if calculationResult is PremiumBreakdown {
            return calculationResult;
        }
        lastError = calculationResult;
        boolean transientError = isTransientConnectionError(calculationResult);
        if !transientError || attempt >= maxRetryAttempts {
            break;
        }
        decimal backoffSeconds = retryBaseDelaySeconds * (2 ^ (attempt - 1));
        log:printWarn("Transient error while calculating premium, retrying",
                policyId = policyId, attempt = attempt, backoffSeconds = backoffSeconds, 'error = lastError);
        runtime:sleep(backoffSeconds);
    }
    return lastError;
}

# Persists the bound policy (using an already-calculated premium breakdown) into the
# policies and ledger_entries tables within a single database transaction. Rolls back both
# inserts if either one fails. This is attempted only once - a partially committed
# transaction must never be blindly retried.
#
# + bindRequest - the incoming policy bind request
# + premiumBreakdown - the already-calculated premium breakdown
# + return - the response to return to the caller, or an error on failure
function persistPolicyInTransaction(PolicyBindRequest bindRequest, PremiumBreakdown premiumBreakdown)
        returns PolicyBoundResponse|error {
    string policyId = bindRequest.policyId;
    string customerId = bindRequest.customerId;
    decimal coverageAmount = bindRequest.coverageAmount;
    RiskTier riskTier = bindRequest.riskTier;

    PolicyBoundResponse|error result = trap persistPolicy(policyId, customerId, coverageAmount, riskTier, premiumBreakdown);
    return result;
}

function persistPolicy(string policyId, string customerId, decimal coverageAmount, RiskTier riskTier,
        PremiumBreakdown premiumBreakdown) returns PolicyBoundResponse|error {
    PolicyBoundResponse boundResponse;
    decimal totalPremium = premiumBreakdown.baseAmount + premiumBreakdown.taxAmount + premiumBreakdown.brokerFee;
    transaction {
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

# Orchestrates the full bind operation: retries only the read-only premium calculation,
# then attempts the transactional inserts exactly once. Neither step is retried as a whole -
# any transaction failure is surfaced immediately so the caller can fall back to the DLQ.
#
# + bindRequest - the incoming policy bind request
# + return - the successful bind response, or the encountered error
function bindPolicy(PolicyBindRequest bindRequest) returns PolicyBoundResponse|error {
    PremiumBreakdown premiumBreakdown = check calculatePremiumWithRetry(bindRequest);
    return persistPolicyInTransaction(bindRequest, premiumBreakdown);
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
