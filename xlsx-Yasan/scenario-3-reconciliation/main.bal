import ballerina/file;
import ballerina/io;
import ballerina/time;
import ballerina/xlsx;

configurable string ledgerPath = "../fixtures/internal-ledger.xlsx";
configurable string reportPath = "reconciliation-report.xlsx";
configurable string errorLogPath = "reconciliation-errors.log";

# Reconciles a statement workbook (received as raw bytes) against the configured ledger,
# writes the report workbook, and returns the mismatch summary.
#
# + statementBytes - Raw bytes of the statement XLSX workbook
# + statementLabel - A label identifying the statement (e.g. the original file name), recorded in the Run Info sheet
# + return - The reconciliation summary, or an error
public function reconcileStatement(byte[] statementBytes, string statementLabel) returns ReconcileResponse|error {
    // The statement bytes are written to a temporary file so the full parseSheet option set
    // (header row offset, fail-safe mode) can be used, since that is only available on the
    // file-based parsing entry point.
    string tempStatementPath = check file:createTemp(suffix = ".xlsx");

    ReconcileResponse? successResult = ();
    error? failure = ();
    do {
        check io:fileWriteBytes(tempStatementPath, statementBytes);

        // The statement sheet starts with a free-text bank/account banner row before the
        // real header row, so the header and data start rows must be shifted down by one.
        // Fail-safe mode is enabled so a row with a malformed cell (e.g. a non-numeric
        // Amount) is skipped and logged instead of aborting the entire run. The log file
        // is appended to across runs so the history of skipped rows is preserved.
        StatementRow[] statementRows = check xlsx:parseSheet(tempStatementPath, "Statement", {
            headerRowIndex: 1,
            dataStartRowIndex: 2,
            failSafe: {
                enableConsoleLogs: true,
                fileOutputMode: {
                    filePath: errorLogPath,
                    contentType: xlsx:RAW_AND_METADATA,
                    fileWriteOption: xlsx:APPEND
                }
            }
        });

        // The raw row count (unaffected by type-conversion failures) tells us how many
        // data rows the sheet actually contained, so the difference against the
        // successfully parsed rows gives the number of rows fail-safe mode skipped.
        string[][] rawStatementRows = check xlsx:parseSheet(tempStatementPath, "Statement", {
            headerRowIndex: 1,
            dataStartRowIndex: 2
        });
        int skippedRowCount = rawStatementRows.length() - statementRows.length();

        xlsx:Workbook ledgerWorkbook = check xlsx:fromFile(ledgerPath);
        xlsx:Table ledgerTable = check ledgerWorkbook.getTable("LedgerEntries");
        LedgerRow[] ledgerRows = check ledgerTable.getRows();
        check ledgerWorkbook.close();

        Mismatch[] mismatches = reconcile(statementRows, ledgerRows);
        // Each run reports mismatches for that run only, so the sheet must be replaced
        // rather than appended to - appending would keep accumulating stale findings from
        // every previous run on top of the current ones.
        check xlsx:writeSheet(mismatches, reportPath, "Mismatches", sheetWriteMode = xlsx:REPLACE);

        string runTimestamp = time:utcToString(time:utcNow());
        RunInfo[] runInfo = [
            {runTimestamp, statementFile: statementLabel, skippedRowCount}
        ];
        check xlsx:writeSheet(runInfo, reportPath, "Run Info", sheetWriteMode = xlsx:REPLACE);

        successResult = {mismatches, skippedRowCount};
    } on fail error e {
        failure = e;
    }

    // The temp file is always removed, whether the reconciliation above succeeded or failed.
    error? cleanupError = file:remove(tempStatementPath);
    if cleanupError is error {
        // Cleanup failures should not mask the actual reconciliation result.
    }

    if successResult is ReconcileResponse {
        return successResult;
    }
    return failure ?: error("Reconciliation failed for an unknown reason");
}

function reconcile(StatementRow[] statementRows, LedgerRow[] ledgerRows) returns Mismatch[] {
    map<LedgerRow> ledgerByRef = {};
    foreach LedgerRow entry in ledgerRows {
        ledgerByRef[entry.txnRef] = entry;
    }

    Mismatch[] mismatches = [];
    map<true> seenRefs = {};
    foreach StatementRow txn in statementRows {
        seenRefs[txn.transactionId] = true;
        LedgerRow? entry = ledgerByRef[txn.transactionId];
        if entry is () {
            mismatches.push({
                txnRef: txn.transactionId,
                kind: "MISSING_IN_LEDGER",
                statementAmount: txn.amount,
                ledgerAmount: ()
            });
        } else if entry.amount != txn.amount {
            mismatches.push({
                txnRef: txn.transactionId,
                kind: "AMOUNT_MISMATCH",
                statementAmount: txn.amount,
                ledgerAmount: entry.amount
            });
        }
    }
    foreach LedgerRow entry in ledgerRows {
        if !seenRefs.hasKey(entry.txnRef) {
            mismatches.push({
                txnRef: entry.txnRef,
                kind: "MISSING_ON_STATEMENT",
                statementAmount: (),
                ledgerAmount: entry.amount
            });
        }
    }
    return mismatches;
}
