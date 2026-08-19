
import ballerina/sql;
import ballerina/http;

function processUnreconciled() returns error? {
    stream<LedgerEntry, sql:Error?> entries = ledgerClient->query(
        `SELECT entry_id as entryId, account_id as accountId, amount, entry_type as entryType,
                created_at as createdAt FROM ledger_entries WHERE reconciled = false LIMIT 500`);
    check from LedgerEntry entry in entries
        do {
            http:Response _ = check reconciliationClient->post("/reconcile", entry);
            _ = check ledgerClient->execute(
                `UPDATE ledger_entries SET reconciled = true WHERE entry_id = ${entry.entryId}`);
        };
}