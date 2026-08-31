import ballerina/xlsx;

const string EXPENSE_SHEET_NAME = "Expense Report";
const string QUARANTINE_SHEET_NAME = "Rejected Rows";
const int REPORTING_PERIOD_ROW_INDEX = 1;
const int REPORTING_PERIOD_COLUMN_INDEX = 1;
const int HEADER_ROW_INDEX = 2;
const int DATA_START_ROW_INDEX = 3;
const int EMPLOYEE_ID_COLUMN_INDEX = 0;
const int AMOUNT_USD_COLUMN_INDEX = 5;
const string TOTAL_ROW_MARKER = "TOTAL";
const decimal MIN_AMOUNT_USD = 0d;
const decimal MAX_AMOUNT_USD = 10000d;
const decimal TOTAL_MATCH_TOLERANCE = 0.01d;

final string[] EXPENSE_COLUMN_HEADERS = [
    "Employee ID",
    "Employee Name",
    "Department",
    "Expense Date",
    "Category",
    "Amount (USD)",
    "Receipt Attached"
];

final string[] QUARANTINE_SHEET_HEADERS = [...EXPENSE_COLUMN_HEADERS, "Rejection Reason"];

# Checks the business rules that binding alone cannot enforce: amount range and category membership.
#
# + expenseEntry - The entry bound from the sheet
# + return - A rejection reason string if the entry is invalid, or `()` if it is valid
function findEntryRejectionReason(ExpenseEntry expenseEntry) returns string? {
    decimal amountUsd = expenseEntry.amountUsd;
    if amountUsd <= MIN_AMOUNT_USD || amountUsd > MAX_AMOUNT_USD {
        return string `Amount (USD) ${amountUsd} must be greater than 0 and at most ${MAX_AMOUNT_USD}.`;
    }

    string categoryText = expenseEntry.category;
    match categoryText {
        "TRAVEL"|"MEALS"|"ACCOMMODATION"|"SUPPLIES"|"OTHER" => {
            return ();
        }
        _ => {
            return string `Category '${categoryText}' must be one of TRAVEL, MEALS, ACCOMMODATION, SUPPLIES, OTHER.`;
        }
    }
}

# Result of scanning the sheet for a trailing TOTAL row.
type DataRowScanResult record {|
    int dataRowCount;
    boolean hasTotalRow;
|};

# Result of processing all data rows: the accepted entries and the rejected rows.
type RowProcessingResult record {|
    ExpenseEntry[] acceptedEntries;
    RejectedExpenseRow[] rejectedRows;
|};

# Determines how many data rows should be bound as expense entries, excluding a trailing
# TOTAL row (where the Employee ID cell reads 'TOTAL', case-insensitively) if one is present.
#
# + sheet - The sheet being read
# + return - The number of data rows to bind, and whether a trailing TOTAL row was found, or an xlsx error
function resolveDataRowCount(xlsx:Sheet sheet) returns DataRowScanResult|xlsx:Error {
    int totalRowCount = check sheet.getRowCount();
    int availableDataRows = totalRowCount - DATA_START_ROW_INDEX;
    if availableDataRows <= 0 {
        return {dataRowCount: 0, hasTotalRow: false};
    }

    int lastRowIndex = totalRowCount - 1;
    string|xlsx:Error lastRowFirstCell = sheet.getCell(lastRowIndex, EMPLOYEE_ID_COLUMN_INDEX);
    if lastRowFirstCell is xlsx:Error {
        return {dataRowCount: availableDataRows, hasTotalRow: false};
    }
    boolean hasTotalRow = lastRowFirstCell.trim().toUpperAscii() == TOTAL_ROW_MARKER;
    int dataRowCount = hasTotalRow ? availableDataRows - 1 : availableDataRows;
    return {dataRowCount, hasTotalRow};
}

# Reads the sheet's own TOTAL row amount cell as a computed decimal value (formula cells resolve
# to their cached computed value, not the formula text).
#
# + sheet - The sheet being read
# + totalRowIndex - 0-based row index of the TOTAL row
# + return - The computed total amount, or an xlsx error if the cell cannot be read
function readSheetTotalAmount(xlsx:Sheet sheet, int totalRowIndex) returns decimal|xlsx:Error {
    return sheet.getCell(totalRowIndex, AMOUNT_USD_COLUMN_INDEX);
}

# Fetches the original cell values of a data row, for inclusion in the quarantine workbook.
# Falls back to an empty array in the unlikely case the raw row itself cannot be read.
#
# + sheet - The sheet being read
# + entryIndex - 0-based index within the data window
# + return - The row's original cell values in column order
function fetchRawRow(xlsx:Sheet sheet, int entryIndex) returns string[] {
    string[]|xlsx:Error rawRowResult = sheet.getRow(entryIndex, {
        headerRowIndex: HEADER_ROW_INDEX,
        caseInsensitiveHeaders: true
    });
    if rawRowResult is xlsx:Error {
        return [];
    }
    return rawRowResult;
}

# Binds and validates every data row, collecting accepted entries and rejected rows separately.
# Rows that fail binding or validation are excluded from the accepted entries but retain their
# original cell values and a reason, for the quarantine workbook.
#
# + sheet - The sheet being read
# + dataRowCount - The number of data rows to process (TOTAL row already excluded)
# + return - The accepted entries and the rejected rows
function processDataRows(xlsx:Sheet sheet, int dataRowCount) returns RowProcessingResult {
    ExpenseEntry[] acceptedEntries = [];
    RejectedExpenseRow[] rejectedRows = [];

    foreach int entryIndex in 0 ..< dataRowCount {
        int rowNumber = DATA_START_ROW_INDEX + 1 + entryIndex;

        ExpenseEntry|xlsx:Error boundEntryResult = sheet.getRow(entryIndex, {
            headerRowIndex: HEADER_ROW_INDEX,
            caseInsensitiveHeaders: true
        });
        if boundEntryResult is xlsx:Error {
            rejectedRows.push({
                rowNumber,
                originalValues: fetchRawRow(sheet, entryIndex),
                reason: boundEntryResult.message()
            });
            continue;
        }

        ExpenseEntry expenseEntry = boundEntryResult;
        string? rejectionReason = findEntryRejectionReason(expenseEntry);
        if rejectionReason is string {
            rejectedRows.push({
                rowNumber,
                originalValues: fetchRawRow(sheet, entryIndex),
                reason: rejectionReason
            });
            continue;
        }

        acceptedEntries.push(expenseEntry);
    }

    return {acceptedEntries, rejectedRows};
}

# Builds an in-memory quarantine workbook containing a single 'Rejected Rows' sheet with each
# rejected row's original cell values plus a 'Rejection Reason' column, then serializes it to bytes.
#
# + rejectedRows - The rows that failed binding or validation
# + return - The base64-encoded quarantine workbook, or an error if it could not be built
function buildQuarantineWorkbookBase64(RejectedExpenseRow[] rejectedRows) returns string|error {
    xlsx:Workbook quarantineWorkbook = new;
    xlsx:Sheet|xlsx:Error quarantineSheetResult = quarantineWorkbook.createSheet(QUARANTINE_SHEET_NAME);
    if quarantineSheetResult is xlsx:Error {
        error? closeResult = quarantineWorkbook.close();
        return quarantineSheetResult;
    }
    xlsx:Sheet quarantineSheet = quarantineSheetResult;

    string[][] quarantineRows = [QUARANTINE_SHEET_HEADERS];
    foreach RejectedExpenseRow rejectedRow in rejectedRows {
        quarantineRows.push([...rejectedRow.originalValues, rejectedRow.reason]);
    }

    xlsx:Error? putRowsResult = quarantineSheet.putRows(quarantineRows);
    if putRowsResult is xlsx:Error {
        error? closeResult = quarantineWorkbook.close();
        return putRowsResult;
    }

    byte[]|xlsx:Error quarantineBytesResult = quarantineWorkbook.toBytes();
    error? closeResult = quarantineWorkbook.close();
    if quarantineBytesResult is xlsx:Error {
        return quarantineBytesResult;
    }

    return quarantineBytesResult.toBase64();
}

# Processes an uploaded XLSX workbook (as raw bytes) entirely in memory, binding what parses and
# collecting every failing row instead of rejecting the whole upload.
#
# A trailing TOTAL row (Employee ID cell reading 'TOTAL') is detected and excluded from processing;
# when present, its Amount (USD) formula cell is read as its computed value and checked against the
# sum of the accepted amounts.
#
# + workbookBytes - The raw bytes of the uploaded .xlsx workbook
# + return - The upload response on success, a typed TOTAL mismatch error, or a generic error for
# structural failures (invalid workbook, missing sheet, missing reporting period)
function processExpenseWorkbook(byte[] workbookBytes) returns ExpenseUploadResponse|ExpenseTotalMismatchError|error {
    xlsx:Workbook|xlsx:Error workbook = xlsx:fromBytes(workbookBytes);
    if workbook is xlsx:Error {
        return error(string `The uploaded file is not a valid .xlsx workbook: ${workbook.message()}`);
    }

    xlsx:Sheet|xlsx:Error sheet = workbook.getSheet(EXPENSE_SHEET_NAME);
    if sheet is xlsx:Error {
        error? closeResult = workbook.close();
        return error(string `Workbook does not contain a sheet named '${EXPENSE_SHEET_NAME}'.`);
    }

    string|xlsx:Error reportingPeriodResult = sheet.getCell(REPORTING_PERIOD_ROW_INDEX, REPORTING_PERIOD_COLUMN_INDEX);
    if reportingPeriodResult is xlsx:Error {
        error? closeResult = workbook.close();
        return error(string `Cell B2 (reporting period) could not be read: ${reportingPeriodResult.message()}`);
    }
    string reportingPeriod = reportingPeriodResult;

    DataRowScanResult|xlsx:Error dataRowScanResult = resolveDataRowCount(sheet);
    if dataRowScanResult is xlsx:Error {
        error? closeResult = workbook.close();
        return error(string `Unable to determine the data row range: ${dataRowScanResult.message()}`);
    }
    int dataRowCount = dataRowScanResult.dataRowCount;
    boolean hasTotalRow = dataRowScanResult.hasTotalRow;

    RowProcessingResult rowProcessingResult = processDataRows(sheet, dataRowCount);
    ExpenseEntry[] acceptedEntries = rowProcessingResult.acceptedEntries;
    RejectedExpenseRow[] rejectedRows = rowProcessingResult.rejectedRows;

    decimal|xlsx:Error|() sheetTotalResult = ();
    if hasTotalRow {
        int totalRowIndex = DATA_START_ROW_INDEX + dataRowCount;
        sheetTotalResult = readSheetTotalAmount(sheet, totalRowIndex);
    }

    error? closeResult = workbook.close();

    if sheetTotalResult is xlsx:Error {
        return error(string `The TOTAL row's Amount (USD) cell could not be read as a number: ${sheetTotalResult.message()}`);
    }
    decimal? sheetTotalAmountUsd = sheetTotalResult;

    decimal totalAmountUsd = 0d;
    map<decimal> perDepartment = {};
    foreach ExpenseEntry expenseEntry in acceptedEntries {
        totalAmountUsd += expenseEntry.amountUsd;
        decimal currentDepartmentTotal = perDepartment.hasKey(expenseEntry.department) ? perDepartment.get(expenseEntry.department) : 0d;
        perDepartment[expenseEntry.department] = currentDepartmentTotal + expenseEntry.amountUsd;
    }

    if sheetTotalAmountUsd is decimal {
        decimal totalDifference = sheetTotalAmountUsd > totalAmountUsd
            ? sheetTotalAmountUsd - totalAmountUsd
            : totalAmountUsd - sheetTotalAmountUsd;
        if totalDifference > TOTAL_MATCH_TOLERANCE {
            return error ExpenseTotalMismatchError("TOTAL_MISMATCH",
                    sheetTotalAmountUsd = sheetTotalAmountUsd, computedTotalAmountUsd = totalAmountUsd);
        }
    }

    string|error quarantineWorkbookBase64Result = buildQuarantineWorkbookBase64(rejectedRows);
    if quarantineWorkbookBase64Result is error {
        return error(string `Unable to build the quarantine workbook: ${quarantineWorkbookBase64Result.message()}`);
    }

    ExpenseUploadSummary summary = {
        reportingPeriod,
        totalEntries: acceptedEntries.length(),
        totalAmountUsd,
        perDepartment
    };

    return {
        acceptedCount: acceptedEntries.length(),
        rejectedCount: rejectedRows.length(),
        summary,
        quarantineWorkbookBase64: quarantineWorkbookBase64Result
    };
}
