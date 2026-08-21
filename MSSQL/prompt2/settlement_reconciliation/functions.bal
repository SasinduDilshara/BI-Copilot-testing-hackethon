
import ballerina/sql;
import ballerina/log;
import ballerina/lang.runtime;

const int MAX_RETRIES = 2;
const decimal BASE_BACKOFF_SECONDS = 0.4;

// MSSQL error codes / SQL state for a unique constraint / duplicate key violation.
const int MSSQL_ERROR_UNIQUE_CONSTRAINT = 2627;
const int MSSQL_ERROR_DUPLICATE_KEY_INDEX = 2601;
const string SQL_STATE_INTEGRITY_CONSTRAINT_VIOLATION = "23000";

function insertSettlementBatch(SettlementRecord[] records) returns error? {
    SettlementRecord[] pendingRecords = records;
    int attempt = 0;

    while pendingRecords.length() > 0 {
        SettlementRecord[]|error failedRecords = executeSettlementBatch(pendingRecords);
        if failedRecords is error {
            return failedRecords;
        }

        if failedRecords.length() == 0 {
            return;
        }

        if attempt >= MAX_RETRIES {
            check deadLetterSettlements(failedRecords, string `Batch insert failed after ${attempt} retries`);
            return;
        }

        decimal backoffSeconds = BASE_BACKOFF_SECONDS * (2 ^ attempt);
        log:printWarn("Retrying failed settlement rows",
                failedCount = failedRecords.length(), attempt = attempt + 1, backoffSeconds = backoffSeconds);
        runtime:sleep(backoffSeconds);

        pendingRecords = failedRecords;
        attempt += 1;
    }
}

# Executes a batch insert for the given records and returns the subset of records that
# genuinely failed. Records flagged by sql:BatchExecuteError as failed (or ambiguous, when the
# driver stopped processing early) are re-checked individually so that duplicate-key violations
# — caused by the processor API resending the same settlement — can be classified as a
# successful no-op instead of a real failure.
function executeSettlementBatch(SettlementRecord[] records) returns SettlementRecord[]|error {
    sql:ParameterizedQuery[] queries = from SettlementRecord r in records
        select `INSERT INTO settlements (settlementId, storeId, amount, batchDate)
                VALUES (${r.settlementId}, ${r.storeId}, ${r.amount}, ${r.batchDate})`;

    sql:ExecutionResult[]|sql:Error result = settlementClient->batchExecute(queries);

    if result is sql:ExecutionResult[] {
        return [];
    }

    if result is sql:BatchExecuteError {
        sql:BatchExecuteErrorDetail detail = result.detail();
        sql:ExecutionResult[] executionResults = detail.executionResults;
        log:printError("Batch insert reported per-command failures", 'error = result,
                errorCode = detail.errorCode, sqlState = detail.sqlState);
        SettlementRecord[] flaggedRecords = extractFailedRecords(records, executionResults);
        return classifyFlaggedRecords(flaggedRecords);
    }

    log:printError("Batch insert failed with a non-batch SQL error", 'error = result);
    return result;
}

# Compares each command's execution result against the original records to determine which
# ones were flagged as failed by the batch call. If the driver stopped processing after the
# first failure, executionResults may be shorter than the input batch — any record without a
# corresponding result is treated as flagged so it gets individually re-checked.
function extractFailedRecords(SettlementRecord[] records, sql:ExecutionResult[] executionResults)
        returns SettlementRecord[] {
    SettlementRecord[] flaggedRecords = [];
    foreach int i in 0 ..< records.length() {
        if i >= executionResults.length() {
            flaggedRecords.push(records[i]);
            continue;
        }
        int? affectedRowCount = executionResults[i].affectedRowCount;
        if affectedRowCount is int && affectedRowCount == -3 {
            flaggedRecords.push(records[i]);
        }
    }
    return flaggedRecords;
}

# Re-executes each flagged record individually to get its own SQL error detail, since
# sql:BatchExecuteError only carries a single top-level errorCode/sqlState for the whole batch.
# Duplicate-key violations are logged and skipped as a successful no-op; every other outcome is
# treated as a genuine failure that must be retried or eventually dead-lettered.
function classifyFlaggedRecords(SettlementRecord[] flaggedRecords) returns SettlementRecord[]|error {
    SettlementRecord[] genuinelyFailedRecords = [];

    foreach SettlementRecord r in flaggedRecords {
        sql:ParameterizedQuery query = `INSERT INTO settlements (settlementId, storeId, amount, batchDate)
                VALUES (${r.settlementId}, ${r.storeId}, ${r.amount}, ${r.batchDate})`;
        sql:ExecutionResult|sql:Error result = settlementClient->execute(query);

        if result is sql:ExecutionResult {
            continue;
        }

        if result is sql:DatabaseError {
            if isDuplicateKeyViolation(result) {
                log:printInfo("Skipping duplicate settlement resend, already inserted",
                        settlementId = r.settlementId);
                continue;
            }
        }

        log:printError("Settlement insert genuinely failed", 'error = result, settlementId = r.settlementId);
        genuinelyFailedRecords.push(r);
    }

    return genuinelyFailedRecords;
}

# Determines whether an sql:DatabaseError represents a unique constraint / duplicate key
# violation, based on the MSSQL error code or the SQL state for integrity constraint violations.
function isDuplicateKeyViolation(sql:DatabaseError databaseError) returns boolean {
    sql:DatabaseErrorDetail detail = databaseError.detail();
    int errorCode = detail.errorCode;
    string? sqlState = detail.sqlState;
    return errorCode == MSSQL_ERROR_UNIQUE_CONSTRAINT
        || errorCode == MSSQL_ERROR_DUPLICATE_KEY_INDEX
        || sqlState == SQL_STATE_INTEGRITY_CONSTRAINT_VIOLATION;
}

# Inserts records that are still failing after all retries into the settlements_dlq table so
# they can be investigated and reconciled manually instead of being silently dropped or retried forever.
function deadLetterSettlements(SettlementRecord[] records, string failureReason) returns error? {
    log:printError("Dead-lettering settlement records after exhausting retries",
            recordCount = records.length(), reason = failureReason);

    sql:ParameterizedQuery[] queries = from SettlementRecord r in records
        select `INSERT INTO settlements_dlq (settlementId, storeId, amount, batchDate, failureReason)
                VALUES (${r.settlementId}, ${r.storeId}, ${r.amount}, ${r.batchDate}, ${failureReason})`;

    sql:ExecutionResult[]|sql:Error result = settlementClient->batchExecute(queries);
    if result is sql:Error {
        log:printError("Failed to write records to settlements_dlq", 'error = result);
        return result;
    }
}