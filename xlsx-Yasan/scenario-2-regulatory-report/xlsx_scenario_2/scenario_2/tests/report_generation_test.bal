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
function testGenerateCreatesAlertsTable() returns error? {
    TransactionAlert[] augustAlerts = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);
    test:assertTrue(augustAlerts.length() > 0, msg = "Expected at least one alert for 2026-08");

    AlertsTableInfo alertsTableInfo = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    test:assertEquals(alertsTableInfo.tableName, "tblAlerts", msg = "Expected the consolidated alerts table");
    test:assertEquals(alertsTableInfo.headers, ["alertId", "branchCode", "region", "alertType", "amountUsd", "raisedOn", "status"],
            msg = "Unexpected headers for the alerts table");
    test:assertEquals(alertsTableInfo.rowCount, augustAlerts.length(),
            msg = "Alerts table row count should equal the number of alerts generated for the month");
    test:assertFalse(alertsTableInfo.hasStrayRowsBelowTable,
            msg = "Alerts table should not have stray rows below it");
}

@test:Config {dependsOn: [testGenerateCreatesAlertsTable]}
function testGenerateAccumulatesYearToDateAcrossMonths() returns error? {
    TransactionAlert[] julyAlerts = check generateSuspiciousTransactionReport("2026-07", TEST_WORKBOOK_PATH);
    test:assertTrue(julyAlerts.length() > 0, msg = "Expected at least one alert for 2026-07");

    TransactionAlert[] augustAlerts = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);

    AlertsTableInfo alertsTableInfo = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);

    int expectedYearToDateAlerts = julyAlerts.length() + augustAlerts.length();
    test:assertEquals(alertsTableInfo.rowCount, expectedYearToDateAlerts,
            msg = "Year-to-date row count in the alerts table should equal the sum of both months' alerts");
}

@test:Config {dependsOn: [testGenerateAccumulatesYearToDateAcrossMonths]}
function testRegenerateSameMonthReplacesOnlyThatMonth() returns error? {
    TransactionAlert[] julyAlerts = check generateSuspiciousTransactionReport("2026-07", TEST_WORKBOOK_PATH);
    TransactionAlert[] augustAlertsFirstRun = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);

    AlertsTableInfo alertsTableInfoAfterFirstAugustRun = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    int rowCountAfterFirstAugustRun = alertsTableInfoAfterFirstAugustRun.rowCount;

    TransactionAlert[] augustAlertsSecondRun = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);
    test:assertEquals(augustAlertsSecondRun.length(), augustAlertsFirstRun.length(),
            msg = "Re-running the same month should yield the same alert count");

    AlertsTableInfo alertsTableInfoAfterSecondAugustRun = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    int rowCountAfterSecondAugustRun = alertsTableInfoAfterSecondAugustRun.rowCount;

    test:assertEquals(rowCountAfterSecondAugustRun, rowCountAfterFirstAugustRun,
            msg = "Re-running the same month must not duplicate rows in the year-to-date table");

    int expectedTotalRows = julyAlerts.length() + augustAlertsFirstRun.length();
    test:assertEquals(rowCountAfterSecondAugustRun, expectedTotalRows,
            msg = "Row count should equal July alerts plus August alerts with no duplication");
}

@test:Config {dependsOn: [testRegenerateSameMonthReplacesOnlyThatMonth]}
function testVerifyDetectsStrayRowsBelowTable() returns error? {
    TransactionAlert[]|error result = generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);
    test:assertTrue(result is TransactionAlert[], msg = "Setup generation should succeed");

    xlsx:Workbook workbook = check xlsx:fromFile(TEST_WORKBOOK_PATH);
    xlsx:Sheet alertsSheet = check workbook.getSheet("Alerts");
    check alertsSheet.setCellByAddress("A100", "stray-alert-id");
    check workbook.save();
    check workbook.close();

    AlertsTableInfo alertsTableInfo = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    test:assertTrue(alertsTableInfo.hasStrayRowsBelowTable,
            msg = "Alerts table info should flag the stray row written below the table range");
}

@test:Config {}
function testGenerateHandlesMonthWithSingleAlert() returns error? {
    TransactionAlert[] juneAlerts = check generateSuspiciousTransactionReport("2026-06", ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertEquals(juneAlerts.length(), 1, msg = "Expected exactly one alert for 2026-06 (EMEA only)");

    AlertsTableInfo alertsTableInfo = check verifySuspiciousTransactionReport(ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertEquals(alertsTableInfo.rowCount, 1, msg = "Alerts table should have exactly one row for 2026-06");
    test:assertFalse(alertsTableInfo.hasStrayRowsBelowTable,
            msg = "Alerts table should not have any blank or stray rows");
}

@test:Config {dependsOn: [testGenerateHandlesMonthWithSingleAlert]}
function testSubsequentGenerationAfterSingleAlertMonthSucceeds() returns error? {
    TransactionAlert[] juneAlerts = check generateSuspiciousTransactionReport("2026-06", ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertEquals(juneAlerts.length(), 1, msg = "Expected exactly one alert for 2026-06 (EMEA only)");

    TransactionAlert[]|error julyResult = generateSuspiciousTransactionReport("2026-07", ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertTrue(julyResult is TransactionAlert[],
            msg = "Generating a later month must succeed after an earlier month left only a single alert");
    TransactionAlert[] julyAlerts = check julyResult;

    AlertsTableInfo alertsTableInfo = check verifySuspiciousTransactionReport(ZERO_ALERT_TEST_WORKBOOK_PATH);
    test:assertFalse(alertsTableInfo.hasStrayRowsBelowTable,
            msg = "Alerts table should not have any blank or stray rows after the second run");
    test:assertEquals(alertsTableInfo.rowCount, juneAlerts.length() + julyAlerts.length(),
            msg = "Alerts table should have the June alert plus all July alerts");
}

@test:Config {}
function testGenerateOverLegacyWorkbookRemovesPerRegionSheets() returns error? {
    check removeFileIfExists(TEST_WORKBOOK_PATH);

    xlsx:Workbook legacyWorkbook = new;
    xlsx:Sheet summarySheet = check legacyWorkbook.createSheet("Summary");
    RegionSummaryRow[] emptySummaryRows = [];
    check summarySheet.putRows(emptySummaryRows);

    string[] legacySheetNames = ["APAC", "EMEA", "AMER"];
    foreach string legacySheetName in legacySheetNames {
        xlsx:Sheet legacySheet = check legacyWorkbook.createSheet(legacySheetName);
        AlertRow[] legacyRows = [
            {
                alertId: "LEGACY-1",
                branchCode: "LEGACY-BR",
                region: legacySheetName,
                alertType: "MANUAL",
                amountUsd: 1000.00,
                raisedOn: {year: 2026, month: 5, day: 1},
                status: "CLOSED"
            }
        ];
        _ = check legacySheet.createTableFromData(string `tbl${legacySheetName}`, legacyRows);
    }
    check legacyWorkbook.saveAs(TEST_WORKBOOK_PATH);
    check legacyWorkbook.close();

    TransactionAlert[] augustAlerts = check generateSuspiciousTransactionReport("2026-08", TEST_WORKBOOK_PATH);
    test:assertTrue(augustAlerts.length() > 0, msg = "Expected at least one alert for 2026-08");

    xlsx:Workbook migratedWorkbook = check xlsx:fromFile(TEST_WORKBOOK_PATH);
    foreach string legacySheetName in legacySheetNames {
        boolean legacySheetExists = check migratedWorkbook.hasSheet(legacySheetName);
        test:assertFalse(legacySheetExists, msg = string `Legacy sheet ${legacySheetName} should have been removed`);
    }
    boolean alertsSheetExists = check migratedWorkbook.hasSheet("Alerts");
    test:assertTrue(alertsSheetExists, msg = "Consolidated Alerts sheet should exist after migration");
    check migratedWorkbook.close();

    AlertsTableInfo alertsTableInfo = check verifySuspiciousTransactionReport(TEST_WORKBOOK_PATH);
    test:assertEquals(alertsTableInfo.rowCount, augustAlerts.length(),
            msg = "Consolidated alerts table should only contain the newly generated month's alerts");
}
