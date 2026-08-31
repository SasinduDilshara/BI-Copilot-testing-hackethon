import ballerina/io;
import ballerina/xlsx;

configurable string statementPath = "../fixtures/bank-statement-2026-08.xlsx";
configurable string ledgerPath = "../fixtures/internal-ledger.xlsx";
configurable string reportPath = "reconciliation-report.xlsx";

public function main() returns error? {
    StatementRow[] statementRows = check xlsx:parseSheet(statementPath, "Statement");

    xlsx:Workbook ledgerWorkbook = check xlsx:fromFile(ledgerPath);
    xlsx:Table ledgerTable = check ledgerWorkbook.getTable("LedgerEntries");
    LedgerRow[] ledgerRows = check ledgerTable.getRows();
    check ledgerWorkbook.close();

    Mismatch[] mismatches = reconcile(statementRows, ledgerRows);
    check xlsx:writeSheet(mismatches, reportPath, "Mismatches");

    io:println(string `Reconciled ${statementRows.length()} statement rows against ` +
            string `${ledgerRows.length()} ledger entries: ${mismatches.length()} mismatch(es).`);
    foreach Mismatch m in mismatches {
        io:println(string `  ${m.kind}: ${m.txnRef}`);
    }
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
