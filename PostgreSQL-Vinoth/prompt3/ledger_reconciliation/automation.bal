
import ballerinax/cdc;
import ballerina/log;
import ballerina/email;

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
        error? alertResult = sendCdcErrorAlert(cdcError);
        if alertResult is error {
            log:printError("Failed to send CDC error alert email", 'error = alertResult);
        }
    }
}

# Sends an alert email notifying operators that a ledger_entries CDC error occurred.
function sendCdcErrorAlert(cdc:Error cdcError) returns error? {
    string errorMessage = cdcError.message();
    email:Message alertEmail = {
        to: alertToAddress,
        subject: "ALERT: Ledger reconciliation CDC error",
        body: string `A CDC error occurred while processing ledger_entries change events.

Error: ${errorMessage}`,
        'from: alertFromAddress
    };
    check alertSmtpClient->sendMessage(alertEmail);
}
