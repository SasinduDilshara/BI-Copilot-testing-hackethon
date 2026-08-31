import ballerina/file;
import ballerina/lang.regexp;
import ballerina/time;
import ballerina/xlsx;

final string monthPatternStr = "^[0-9]{4}-(0[1-9]|1[0-2])$";

# Sentinel alert id used for the single placeholder row written into a freshly created region
# table, since an Excel Table cannot be created with zero data rows. The placeholder is always
# removed the first time real alerts are written to the table.
final string placeholderAlertId = "__PLACEHOLDER__";

# Placeholder row used only to satisfy the Excel Table's minimum-one-data-row requirement when
# a region table is first created. Never left in place once real data is written.
final AlertRow placeholderAlertRow = {
    alertId: placeholderAlertId,
    branchCode: "N/A",
    region: "N/A",
    alertType: "N/A",
    amountUsd: 0,
    raisedOn: {year: 1900, month: 1, day: 1},
    status: "N/A"
};

# Validates that the given month string follows the yyyy-MM format.
#
# + month - the month string to validate
# + return - true if the month string is valid
function isValidMonth(string month) returns boolean {
    regexp:RegExp|error monthPattern = regexp:fromString(monthPatternStr);
    if monthPattern is error {
        return false;
    }
    return monthPattern.isFullMatch(month);
}

# Formats a time:Date as a yyyy-MM string for month comparison.
#
# + alertDate - the date to format
# + return - the month key in yyyy-MM format
function toMonthKey(time:Date alertDate) returns string {
    string monthStr = alertDate.month < 10 ? string `0${alertDate.month}` : alertDate.month.toString();
    return string `${alertDate.year}-${monthStr}`;
}

# Filters the alert store to alerts raised in the given month.
#
# + month - the target month in yyyy-MM format
# + return - the alerts raised within the given month
function filterAlertsByMonth(string month) returns TransactionAlert[] {
    return from TransactionAlert alert in alertStore
        where toMonthKey(alert.raisedOn) == month
        select alert;
}

# Converts alerts into the row shape written to a region's sheet/table.
#
# + regionAlerts - alerts belonging to a single region
# + return - the alert rows ready to be written to a sheet/table
function toAlertRows(TransactionAlert[] regionAlerts) returns AlertRow[] {
    return from TransactionAlert alert in regionAlerts
        select {
            alertId: alert.alertId,
            branchCode: alert.branchCode,
            region: alert.region.toString(),
            alertType: alert.alertType.toString(),
            amountUsd: alert.amountUsd,
            raisedOn: alert.raisedOn,
            status: alert.status.toString()
        };
}

# Returns the Excel table name used for a given region's sheet.
#
# + region - the region
# + return - the table name, e.g. tblAPAC
function tableNameForRegion(Region region) returns string {
    return string `tbl${region.toString()}`;
}

# Removes any existing rows for the given month, and the bootstrap placeholder row, from a
# region's table data, so that re-running generation for the same month replaces that month's
# rows instead of duplicating them, while leaving other months' year-to-date data untouched.
#
# + existingRows - the region table's current data rows
# + month - the month being (re)generated, in yyyy-MM format
# + return - the existing rows with the target month's rows and the placeholder row removed
function removeMonthRows(AlertRow[] existingRows, string month) returns AlertRow[] {
    return from AlertRow row in existingRows
        where row.alertId != placeholderAlertId && toMonthKey(row.raisedOn) != month
        select row;
}

# Opens the workbook at the given path, creating a fresh year-to-date workbook with an
# empty 'Summary' sheet and one empty, named table per region if the file does not exist yet.
#
# + outputPath - the file path of the workbook
# + return - the opened workbook, or an error
function openOrCreateWorkbook(string outputPath) returns xlsx:Workbook|error {
    boolean fileExists = check file:test(outputPath, file:EXISTS);
    if fileExists {
        return xlsx:fromFile(outputPath);
    }

    xlsx:Workbook workbook = new;
    xlsx:Sheet summarySheet = check workbook.createSheet("Summary");
    RegionSummaryRow[] emptySummaryRows = [];
    check summarySheet.putRows(emptySummaryRows);

    Region[] regions = [APAC, EMEA, AMER];
    foreach Region region in regions {
        xlsx:Sheet regionSheet = check workbook.createSheet(region.toString());
        string tableName = tableNameForRegion(region);
        AlertRow[] placeholderRow = [placeholderAlertRow];
        _ = check regionSheet.createTableFromData(tableName, placeholderRow);
    }
    check workbook.saveAs(outputPath);
    return workbook;
}

# Generates or extends the year-to-date Suspicious Transaction Summary workbook at the given
# path with the given month's alerts. If the workbook already exists, each region's table is
# extended in place (existing year-to-date rows are kept, any prior rows for the same month are
# replaced, and the table's range grows to fit) rather than the sheets being replaced. The
# 'Summary' sheet is rebuilt from the resulting year-to-date data across all regions.
#
# + month - the month being generated, in yyyy-MM format
# + outputPath - the file path where the workbook should be written
# + return - the alerts included in this month's run, or an error if generation failed
function generateSuspiciousTransactionReport(string month, string outputPath) returns TransactionAlert[]|error {
    TransactionAlert[] monthAlerts = filterAlertsByMonth(month);

    xlsx:Workbook workbook = check openOrCreateWorkbook(outputPath);

    RegionSummaryRow[] summaryRows = [];
    Region[] regions = [APAC, EMEA, AMER];
    foreach Region region in regions {
        TransactionAlert[] regionMonthAlerts = from TransactionAlert alert in monthAlerts
            where alert.region == region
            select alert;
        AlertRow[] newRows = toAlertRows(regionMonthAlerts);

        string tableName = tableNameForRegion(region);
        xlsx:Table regionTable = check workbook.getTable(tableName);
        AlertRow[] existingRows = check regionTable.getRows();
        AlertRow[] retainedRows = removeMonthRows(existingRows, month);
        AlertRow[] yearToDateRows = [...retainedRows, ...newRows];
        check regionTable.putRows(yearToDateRows);

        if yearToDateRows.length() == 0 {
            continue;
        }
        decimal totalAmount = 0;
        foreach AlertRow row in yearToDateRows {
            totalAmount += row.amountUsd;
        }
        summaryRows.push({
            region: region.toString(),
            alertCount: yearToDateRows.length(),
            totalFlaggedAmountUsd: totalAmount
        });
    }

    xlsx:Sheet summarySheet = check workbook.getSheet("Summary");
    check summarySheet.putRows(summaryRows, sheetWriteMode = xlsx:REPLACE);

    check workbook.save();
    check workbook.close();
    return monthAlerts;
}

# Builds the table metadata and stray-row diagnostic for a single region's table.
#
# + workbook - the open workbook
# + region - the region whose table should be inspected
# + return - the region's table metadata, or an error
function buildRegionTableInfo(xlsx:Workbook workbook, Region region) returns RegionTableInfo|error {
    string tableName = tableNameForRegion(region);
    xlsx:Table regionTable = check workbook.getTable(tableName);

    string[] headers = check regionTable.getHeaders();
    int rowCount = check regionTable.getRowCount();
    string dataRange = check regionTable.getDataRange();
    boolean hasTotalsRow = check regionTable.hasTotalRow();

    xlsx:CellRange tableCellRange = check regionTable.getCellRange();
    xlsx:Sheet regionSheet = check workbook.getSheet(region.toString());
    xlsx:CellRange? usedCellRange = check regionSheet.getUsedCellRange();
    boolean hasStrayRowsBelowTable = false;
    if usedCellRange is xlsx:CellRange {
        hasStrayRowsBelowTable = usedCellRange.lastRowIndex > tableCellRange.lastRowIndex;
    }

    return {
        region: region.toString(),
        tableName: tableName,
        headers: headers,
        rowCount: rowCount,
        dataRange: dataRange,
        hasTotalsRow: hasTotalsRow,
        hasStrayRowsBelowTable: hasStrayRowsBelowTable
    };
}

# Opens the workbook at the given path read-only and builds the table metadata for every region.
#
# + workbookPath - the file path of the workbook to verify
# + return - the per-region table metadata, or an error if the workbook or a table is missing
function verifySuspiciousTransactionReport(string workbookPath) returns RegionTableInfo[]|error {
    xlsx:Workbook workbook = check xlsx:fromFile(workbookPath);

    RegionTableInfo[] regionTables = [];
    Region[] regions = [APAC, EMEA, AMER];
    foreach Region region in regions {
        RegionTableInfo regionTableInfo = check buildRegionTableInfo(workbook, region);
        regionTables.push(regionTableInfo);
    }

    check workbook.close();
    return regionTables;
}
