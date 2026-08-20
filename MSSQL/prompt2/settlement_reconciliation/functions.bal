
import ballerina/sql;
import ballerina/log;
import ballerina/lang.runtime;

const int MAX_RETRIES = 2;
const decimal BASE_BACKOFF_SECONDS = 0.4;

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

# Executes a batch insert for the given records and returns the subset of records whose
# individual insert command failed, based on the per-command results in sql:BatchExecuteError.
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
        return extractFailedRecords(records, executionResults);
    }

    log:printError("Batch insert failed with a non-batch SQL error", 'error = result);
    return result;
}

# Compares each command's execution result against the original records to determine which
# ones failed. If the driver stopped processing after the first failure, executionResults may
# be shorter than the input batch — any record without a corresponding result is treated as
# failed so it gets retried rather than silently dropped.
function extractFailedRecords(SettlementRecord[] records, sql:ExecutionResult[] executionResults)
        returns SettlementRecord[] {
    SettlementRecord[] failedRecords = [];
    foreach int i in 0 ..< records.length() {
        if i >= executionResults.length() {
            failedRecords.push(records[i]);
            continue;
        }
        int? affectedRowCount = executionResults[i].affectedRowCount;
        if affectedRowCount is int && affectedRowCount == -3 {
            failedRecords.push(records[i]);
        }
    }
    return failedRecords;
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