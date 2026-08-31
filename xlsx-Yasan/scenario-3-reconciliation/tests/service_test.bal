import ballerina/http;
import ballerina/io;
import ballerina/test;

final http:Client reconciliationClient = check new ("http://localhost:8080");

@test:Config {}
function testReconcileEndpointSkipsMalformedRowAndReturnsSummary() returns error? {
    byte[] statementBytes = check io:fileReadBytes("../fixtures/bank-statement-2026-09.xlsx");

    ReconcileResponse response = check reconciliationClient->post("/reconciliation/reconcile", statementBytes,
            mediaType = "application/octet-stream");

    test:assertEquals(response.skippedRowCount, 1, msg = "The malformed row (non-numeric Amount) should be skipped");
    test:assertEquals(response.mismatches.length(), 19,
            msg = "5 September statement rows have no matching ledger entry and all 14 ledger entries are unmatched");

    Mismatch[] missingInLedger = from Mismatch m in response.mismatches
        where m.kind == "MISSING_IN_LEDGER"
        select m;
    test:assertEquals(missingInLedger.length(), 5, msg = "Expected 5 statement rows missing in the ledger");

    Mismatch[] missingOnStatement = from Mismatch m in response.mismatches
        where m.kind == "MISSING_ON_STATEMENT"
        select m;
    test:assertEquals(missingOnStatement.length(), 14, msg = "Expected all 14 ledger entries missing on the statement");
}

@test:Config {}
function testReconcileEndpointRejectsInvalidWorkbookBytes() returns error? {
    byte[] garbageBytes = "this is not a valid xlsx workbook".toBytes();

    http:Response response = check reconciliationClient->post("/reconciliation/reconcile", garbageBytes,
            mediaType = "application/octet-stream");

    test:assertEquals(response.statusCode, 500,
            msg = "Bytes that are not a valid xlsx workbook should fail during processing with a 500");
}
