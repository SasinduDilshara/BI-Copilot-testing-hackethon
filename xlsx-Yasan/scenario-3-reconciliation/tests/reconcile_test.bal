import ballerina/test;
import ballerina/time;

final time:Date testDate = {year: 2026, month: 9, day: 1};

@test:Config {}
function testReconcileDetectsAllMismatchKinds() {
    StatementRow[] statementRows = [
        {transactionId: "TXN-1", valueDate: testDate, description: "Matches", amount: 100.00d, balance: 100.00d},
        {transactionId: "TXN-2", valueDate: testDate, description: "Amount differs", amount: 50.00d, balance: 150.00d},
        {transactionId: "TXN-3", valueDate: testDate, description: "Not in ledger", amount: 75.00d, balance: 225.00d}
    ];
    LedgerRow[] ledgerRows = [
        {entryId: "LED-1", txnRef: "TXN-1", postedDate: testDate, amount: 100.00d, account: "1200-AR"},
        {entryId: "LED-2", txnRef: "TXN-2", postedDate: testDate, amount: 60.00d, account: "1200-AR"},
        {entryId: "LED-3", txnRef: "TXN-4", postedDate: testDate, amount: 90.00d, account: "1200-AR"}
    ];

    Mismatch[] mismatches = reconcile(statementRows, ledgerRows);

    test:assertEquals(mismatches.length(), 3, msg = "Expected exactly 3 mismatches");

    Mismatch[] amountMismatches = from Mismatch m in mismatches
        where m.kind == "AMOUNT_MISMATCH"
        select m;
    test:assertEquals(amountMismatches.length(), 1, msg = "Expected exactly 1 amount mismatch");
    test:assertEquals(amountMismatches[0].txnRef, "TXN-2", msg = "Amount mismatch should be for TXN-2");
    test:assertEquals(amountMismatches[0].statementAmount, 50.00d, msg = "Statement amount should be preserved");
    test:assertEquals(amountMismatches[0].ledgerAmount, 60.00d, msg = "Ledger amount should be preserved");

    Mismatch[] missingInLedger = from Mismatch m in mismatches
        where m.kind == "MISSING_IN_LEDGER"
        select m;
    test:assertEquals(missingInLedger.length(), 1, msg = "Expected exactly 1 missing-in-ledger mismatch");
    test:assertEquals(missingInLedger[0].txnRef, "TXN-3", msg = "Missing-in-ledger mismatch should be for TXN-3");

    Mismatch[] missingOnStatement = from Mismatch m in mismatches
        where m.kind == "MISSING_ON_STATEMENT"
        select m;
    test:assertEquals(missingOnStatement.length(), 1, msg = "Expected exactly 1 missing-on-statement mismatch");
    test:assertEquals(missingOnStatement[0].txnRef, "TXN-4", msg = "Missing-on-statement mismatch should be for TXN-4");
}

@test:Config {}
function testReconcileReturnsNoMismatchesWhenFullyMatched() {
    StatementRow[] statementRows = [
        {transactionId: "TXN-10", valueDate: testDate, description: "Matches", amount: 500.00d, balance: 500.00d}
    ];
    LedgerRow[] ledgerRows = [
        {entryId: "LED-10", txnRef: "TXN-10", postedDate: testDate, amount: 500.00d, account: "1200-AR"}
    ];

    Mismatch[] mismatches = reconcile(statementRows, ledgerRows);

    test:assertEquals(mismatches.length(), 0, msg = "Expected no mismatches when statement and ledger fully match");
}
