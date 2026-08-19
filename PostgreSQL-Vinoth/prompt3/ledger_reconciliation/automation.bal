
import ballerinax/cdc;
import ballerina/log;

service on ledgerCdcListener {

    remote function onCreate(record {} afterEntry, string tableName) returns error? {
        LedgerEntryChangeEvent entryChange = check afterEntry.cloneWithType();
        check reconcileEntry(entryChange);
    }

    remote function onUpdate(record {} beforeEntry, record {} afterEntry, string tableName) returns error? {
        LedgerEntryChangeEvent entryChange = check afterEntry.cloneWithType();
        check reconcileEntry(entryChange);
    }

    remote function onError(cdc:Error cdcError) {
        log:printError("Error occurred while processing ledger_entries CDC event", 'error = cdcError);
    }
}
