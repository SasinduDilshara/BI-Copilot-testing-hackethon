import ballerina/file;
import ballerina/test;
import ballerina/xlsx;

const string TEST_WORKBOOK_PATH = "test_suspicious_transaction_summary.xlsx";
const string ZERO_ALERT_TEST_WORKBOOK_PATH = "test_zero_alert_region.xlsx";

@test:BeforeEach
function removeTestWorkbookIfExists() returns error? {
    check removeFileIfExists(TEST_WORKBOOK_PATH);
    check removeFileIfExists(ZERO_ALERT_TEST_WORKBOOK_PATH);
}

@test:AfterSuite {}
function removeTestWorkbookAfterSuite() returns error? {
    check removeFileIfExists(TEST_WORKBOOK_PATH);
    check removeFileIfExists(ZERO_ALERT_TEST_WORKBOOK_PATH);
}

# Removes the file at the given path if it currently exists.
#
# + workbookPath - the file path to remove
# + return - an error if the check or removal fails
function removeFileIfExists(string workbookPath) returns error? {
    boolean fileExists = check file:test(workbookPath, file:EXISTS);
    if fileExists {
        check file:remove(workbookPath);
    }
}

@test:Config {}
function testGenerateCreatesSummaryAndRegionTables() returns error? {
    TransactionAlert[] augustAlerts = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);
    test:assertTrue(augustAlerts.length() > 0, msg = "Expected at least one alert for 2026-08");

    RegionTableInfo[] regionTables = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    test:assertEquals(regionTables.length(), 3, msg = "Expected exactly three region tables");

    foreach RegionTableInfo regionTableInfo in regionTables {
        test:assertEquals(regionTableInfo.headers, ["alertId", "branchCode", "region", "alertType", "amountUsd", "raisedOn", "status"],
                msg = string `Unexpected headers for ${regionTableInfo.region} table`);
        test:assertFalse(regionTableInfo.hasStrayRowsBelowTable,
                msg = string `${regionTableInfo.region} table should not have stray rows below it`);
    }
}

@test:Config {dependsOn: [testGenerateCreatesSummaryAndRegionTables]}
function testGenerateAccumulatesYearToDateAcrossMonths() returns error? {
    TransactionAlert[] julyAlerts = check generateSuspiciousTransactionReport("2026-07", TEST_WORKBOOK_PATH);
    test:assertTrue(julyAlerts.length() > 0, msg = "Expected at least one alert for 2026-07");

    TransactionAlert[] augustAlerts = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);

    RegionTableInfo[] regionTables = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    int totalYearToDateRows = 0;
    foreach RegionTableInfo regionTableInfo in regionTables {
        totalYearToDateRows += regionTableInfo.rowCount;
    }

    int expectedYearToDateAlerts = julyAlerts.length() + augustAlerts.length();
    test:assertEquals(totalYearToDateRows, expectedYearToDateAlerts,
            msg = "Year-to-date row count across all region tables should equal the sum of both months' alerts");
}

@test:Config {dependsOn: [testGenerateAccumulatesYearToDateAcrossMonths]}
function testRegenerateSameMonthReplacesOnlyThatMonth() returns error? {
    TransactionAlert[] julyAlerts = check generateSuspiciousTransactionReport("2026-07", TEST_WORKBOOK_PATH);
    TransactionAlert[] augustAlertsFirstRun = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);

    RegionTableInfo[] regionTablesAfterFirstAugustRun = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    int rowCountAfterFirstAugustRun = 0;
    foreach RegionTableInfo regionTableInfo in regionTablesAfterFirstAugustRun {
        rowCountAfterFirstAugustRun += regionTableInfo.rowCount;
    }

    TransactionAlert[] augustAlertsSecondRun = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);
    test:assertEquals(augustAlertsSecondRun.length(), augustAlertsFirstRun.length(),
            msg = "Re-running the same month should yield the same alert count");

    RegionTableInfo[] regionTablesAfterSecondAugustRun = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    int rowCountAfterSecondAugustRun = 0;
    foreach RegionTableInfo regionTableInfo in regionTablesAfterSecondAugustRun {
        rowCountAfterSecondAugustRun += regionTableInfo.rowCount;
    }

    test:assertEquals(rowCountAfterSecondAugustRun, rowCountAfterFirstAugustRun,
            msg = "Re-running the same month must not duplicate rows in the year-to-date tables");

    int expectedTotalRows = julyAlerts.length() + augustAlertsFirstRun.length();
    test:assertEquals(rowCountAfterSecondAugustRun, expectedTotalRows,
            msg = "Row count should equal July alerts plus August alerts with no duplication");
}

@test:Config {dependsOn: [testRegenerateSameMonthReplacesOnlyThatMonth]}
function testVerifyDetectsStrayRowsBelowTable() returns error? {
    TransactionAlert[]|error result = generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);
    test:assertTrue(result is TransactionAlert[], msg = "Setup generation should succeed");

    xlsx:Workbook workbook = check xlsx:fromFile(TEST_WORKBOOK_PATH);
    xlsx:Sheet apacSheet = check workbook.getSheet("APAC");
    check apacSheet.setCellByAddress("A100", "stray-alert-id");
    check workbook.save();
    check workbook.close();

    RegionTableInfo[] regionTables = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    RegionTableInfo[] apacTableInfoMatches = from RegionTableInfo regionTableInfo in regionTables
        where regionTableInfo.region == "APAC"
        select regionTableInfo;
    test:assertEquals(apacTableInfoMatches.length(), 1, msg = "Expected exactly one APAC table info entry");

    RegionTableInfo apacTableInfo = apacTableInfoMatches[0];
    test:assertTrue(apacTableInfo.hasStrayRowsBelowTable,
            msg = "APAC table info should flag the stray row written below the table range");
}

@test:Config {}
function testGenerateHandlesRegionWithZeroAlerts() returns error? {
    TransactionAlert[] juneAlerts = check generateSuspiciousTransactionReport("2026-06", ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertEquals(juneAlerts.length(), 1, msg = "Expected exactly one alert for 2026-06 (EMEA only)");

    RegionTableInfo[] regionTables = check verifySuspiciousTransactionReport(ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertEquals(regionTables.length(), 3, msg = "Expected exactly three region table info entries");

    foreach RegionTableInfo regionTableInfo in regionTables {
        if regionTableInfo.region == "EMEA" {
            test:assertEquals(regionTableInfo.rowCount, 1, msg = "EMEA should have exactly one row for 2026-06");
        } else {
            test:assertEquals(regionTableInfo.rowCount, 0,
                    msg = string `${regionTableInfo.region} should have zero rows for 2026-06`);
            test:assertEquals(regionTableInfo.headers, [],
                    msg = string `${regionTableInfo.region} should report no headers when it has no table`);
        }
        test:assertFalse(regionTableInfo.hasStrayRowsBelowTable,
                msg = string `${regionTableInfo.region} should not have any blank or stray rows`);
    }
}

@test:Config {dependsOn: [testGenerateHandlesRegionWithZeroAlerts]}
function testSubsequentGenerationAfterZeroAlertMonthSucceeds() returns error? {
    TransactionAlert[] juneAlerts = check generateSuspiciousTransactionReport("2026-06", ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertEquals(juneAlerts.length(), 1, msg = "Expected exactly one alert for 2026-06 (EMEA only)");

    TransactionAlert[]|error julyResult = generateSuspiciousTransactionReport("2026-07", ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertTrue(julyResult is TransactionAlert[],
            msg = "Generating a later month must succeed after an earlier month left a region with zero alerts");

    RegionTableInfo[] regionTables = check verifySuspiciousTransactionReport(ZERO_ALERT_TEST_WORKBOOK_PATH);
    foreach RegionTableInfo regionTableInfo in regionTables {
        test:assertFalse(regionTableInfo.hasStrayRowsBelowTable,
                msg = string `${regionTableInfo.region} should not have any blank or stray rows after the second run`);
        if regionTableInfo.region == "APAC" {
            test:assertEquals(regionTableInfo.rowCount, 2, msg = "APAC should have its two July alerts");
        } else if regionTableInfo.region == "AMER" {
            test:assertEquals(regionTableInfo.rowCount, 1, msg = "AMER should have its one July alert");
        } else {
            test:assertEquals(regionTableInfo.rowCount, 2,
                    msg = "EMEA should have its June alert plus its one July alert");
        }
    }
}
