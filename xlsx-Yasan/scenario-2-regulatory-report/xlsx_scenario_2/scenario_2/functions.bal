import ballerina/file;
import ballerina/lang.regexp;
import ballerina/time;
import ballerina/xlsx;

final string monthPatternStr = "^[0-9]{4}-(0[1-9]|1[0-2])$";

# Column headers used for every region's Excel table, in column order. Reused whenever a
# region has zero year-to-date alerts and therefore no table exists on its sheet yet.
final string[] alertRowHeaders = ["alertId", "branchCode", "region", "alertType", "amountUsd", "raisedOn", "status"];

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

# Removes any existing rows for the given month from a region's table data, so that
# re-running generation for the same month replaces that month's rows instead of
# duplicating them, while leaving other months' year-to-date data untouched.
#
# + existingRows - the region table's current data rows
# + month - the month being (re)generated, in yyyy-MM format
# + return - the existing rows with the target month's rows removed
function removeMonthRows(AlertRow[] existingRows, string month) returns AlertRow[] {
    return from AlertRow row in existingRows
        where toMonthKey(row.raisedOn) != month
        select row;
}

# Opens the workbook at the given path, creating a fresh year-to-date workbook with an
# empty 'Summary' sheet and one empty sheet per region (with no table yet) if the file does
# not exist. Region tables are created lazily, only once a region has at least one alert.
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
        _ = check workbook.createSheet(region.toString());
    }
    check workbook.saveAs(outputPath);
    return workbook;
}

# Writes a region's year-to-date rows to its sheet. Creates the table if it does not exist yet
# and there is data to write, updates it in place if it already exists, or removes it (and the
# now-stale data row it occupied) if the region has no year-to-date alerts left.
#
# + regionSheet - the region's sheet
# + tableName - the region's table name
# + yearToDateRows - the full set of year-to-date rows for the region, may be empty
# + return - an error if the write fails
function writeRegionTable(xlsx:Sheet regionSheet, string tableName, AlertRow[] yearToDateRows) returns error? {
    xlsx:Table|error existingTable = regionSheet.getTable(tableName);

    if existingTable is xlsx:Table {
        if yearToDateRows.length() == 0 {
            check regionSheet.deleteTable(tableName);
            check regionSheet.deleteRow(1);
            return;
        }
        check existingTable.putRows(yearToDateRows);
        return;
    }

    if !(existingTable is xlsx:TableNotFoundError) {
        return existingTable;
    }
    if yearToDateRows.length() == 0 {
        return;
    }
    _ = check regionSheet.createTableFromData(tableName, yearToDateRows);
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
        xlsx:Sheet regionSheet = check workbook.getSheet(region.toString());
        xlsx:Table|error existingTableForRead = regionSheet.getTable(tableName);
        AlertRow[] existingRows = [];
        if existingTableForRead is xlsx:Table {
            existingRows = check existingTableForRead.getRows();
        } else if !(existingTableForRead is xlsx:TableNotFoundError) {
            return existingTableForRead;
        }
        AlertRow[] retainedRows = removeMonthRows(existingRows, month);
        AlertRow[] yearToDateRows = [...retainedRows, ...newRows];
        check writeRegionTable(regionSheet, tableName, yearToDateRows);

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
    xlsx:Sheet regionSheet = check workbook.getSheet(region.toString());
    xlsx:Table|error regionTable = regionSheet.getTable(tableName);

    if regionTable is xlsx:TableNotFoundError {
        xlsx:CellRange? usedCellRange = check regionSheet.getUsedCellRange();
        return {
            region: region.toString(),
            tableName: tableName,
            headers: [],
            rowCount: 0,
            dataRange: "",
            hasTotalsRow: false,
            hasStrayRowsBelowTable: usedCellRange is xlsx:CellRange
        };
    }
    if regionTable is error {
        return regionTable;
    }

    string[] headers = check regionTable.getHeaders();
    int rowCount = check regionTable.getRowCount();
    string dataRange = check regionTable.getDataRange();
    boolean hasTotalsRow = check regionTable.hasTotalRow();

    xlsx:CellRange tableCellRange = check regionTable.getCellRange();
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
