
import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/sql;

const int MAX_RETRY_COUNT = 2;
const decimal INITIAL_BACKOFF_SECONDS = 1;

# Calls the reconciliation API for the given ledger entry change, retrying with
# exponential backoff. If all retries are exhausted, the entry is dead-lettered.
function reconcileEntry(LedgerEntryChangeEvent entryChange) returns error? {
    string entryId = entryChange.entry_id;
    decimal backoffSeconds = INITIAL_BACKOFF_SECONDS;
    int attempt = 0;
    while true {
        http:Response|error response = reconciliationClient->post("/reconcile", entryChange);
        if response is http:Response {
            sql:ExecutionResult _ = check ledgerClient->execute(
                `UPDATE ledger_entries SET reconciled = true WHERE entry_id = ${entryId}`);
            return;
        }
        attempt += 1;
        if attempt > MAX_RETRY_COUNT {
            check deadLetterEntry(entryId, response.message());
            return;
        }
        log:printWarn("Reconciliation attempt failed, retrying", entryId = entryId, attempt = attempt,
                'error = response);
        runtime:sleep(backoffSeconds);
        backoffSeconds *= 2;
    }
}

# Persists a failed ledger entry into the dead-letter table along with the
# reason it could not be reconciled after retries.
function deadLetterEntry(string entryId, string errorReason) returns error? {
    log:printError("Reconciliation failed after retries, dead-lettering entry", entryId = entryId,
            reason = errorReason);
    sql:ExecutionResult _ = check ledgerClient->execute(
        `INSERT INTO ledger_reconciliation_dlq (entry_id, error_reason) VALUES (${entryId}, ${errorReason})`);
}