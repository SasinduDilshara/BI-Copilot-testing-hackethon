import ballerina/file;
import ballerina/lang.regexp;
import ballerina/time;
import ballerina/xlsx;

final string monthPatternStr = "^[0-9]{4}-(0[1-9]|1[0-2])$";

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

# Builds the per-region summary rows for the given month's alerts.
#
# + monthAlerts - alerts already filtered to the requested month
# + return - one summary row per region that has at least one alert
function buildRegionSummary(TransactionAlert[] monthAlerts) returns RegionSummaryRow[] {
    RegionSummaryRow[] summaryRows = [];
    Region[] regions = [APAC, EMEA, AMER];
    foreach Region region in regions {
        TransactionAlert[] regionAlerts = from TransactionAlert alert in monthAlerts
            where alert.region == region
            select alert;
        if regionAlerts.length() == 0 {
            continue;
        }
        decimal totalAmount = 0;
        foreach TransactionAlert alert in regionAlerts {
            totalAmount += alert.amountUsd;
        }
        summaryRows.push({
            region: region.toString(),
            alertCount: regionAlerts.length(),
            totalFlaggedAmountUsd: totalAmount
        });
    }
    return summaryRows;
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

# Generates the Suspicious Transaction Summary workbook for the given month at the given path.
# Any previously generated file at the same path is removed first so the regeneration
# cleanly overwrites earlier results instead of failing or duplicating rows.
#
# + month - the target month in yyyy-MM format
# + outputPath - the file path where the workbook should be written
# + return - the alerts included in the generated report, or an error if generation failed
function generateSuspiciousTransactionReport(string month, string outputPath) returns TransactionAlert[]|error {
    boolean fileExists = check file:test(outputPath, file:EXISTS);
    if fileExists {
        check file:remove(outputPath);
    }

    TransactionAlert[] monthAlerts = filterAlertsByMonth(month);
    RegionSummaryRow[] summaryRows = buildRegionSummary(monthAlerts);

    xlsx:Workbook workbook = new;
    xlsx:Sheet summarySheet = check workbook.createSheet("Summary");
    check summarySheet.putRows(summaryRows);

    Region[] regions = [APAC, EMEA, AMER];
    foreach Region region in regions {
        TransactionAlert[] regionAlerts = from TransactionAlert alert in monthAlerts
            where alert.region == region
            select alert;
        AlertRow[] alertRows = toAlertRows(regionAlerts);

        xlsx:Sheet regionSheet = check workbook.createSheet(region.toString());
        string tableName = tableNameForRegion(region);
        _ = check regionSheet.createTableFromData(tableName, alertRows);
    }

    check workbook.saveAs(outputPath);
    check workbook.close();
    return monthAlerts;
}
