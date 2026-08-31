import ballerina/xlsx;

const string EXPENSE_SHEET_NAME = "Expense Report";
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

# Validates a single bound expense entry: amount range and category membership.
# Binding (headers, types, required fields) is already enforced natively by `Sheet.getRows`;
# this only checks the business rules that are specific to this endpoint.
#
# + expenseEntry - The entry bound from the sheet
# + rowNumber - The 1-based spreadsheet row number, used for error reporting
# + return - The validated `ExpenseEntry`, or a typed validation error
function validateExpenseEntry(ExpenseEntry expenseEntry, int rowNumber) returns ExpenseEntry|ExpenseValidationError {
    decimal amountUsd = expenseEntry.amountUsd;
    if amountUsd <= MIN_AMOUNT_USD || amountUsd > MAX_AMOUNT_USD {
        return error ExpenseValidationError("Amount out of range",
                rowNumber = rowNumber, column = "Amount (USD)",
                reason = string `Amount (USD) ${amountUsd} must be greater than 0 and at most ${MAX_AMOUNT_USD}.`);
    }

    string categoryText = expenseEntry.category;
    match categoryText {
        "TRAVEL"|"MEALS"|"ACCOMMODATION"|"SUPPLIES"|"OTHER" => {
            return expenseEntry;
        }
        _ => {
            return error ExpenseValidationError("Invalid category",
                    rowNumber = rowNumber, column = "Category",
                    reason = string `Category '${categoryText}' must be one of TRAVEL, MEALS, ACCOMMODATION, SUPPLIES, OTHER.`);
        }
    }
}

# Converts an `xlsx:Error` raised while binding sheet rows into a typed `ExpenseValidationError`,
# identifying the failing row/column from the xlsx error's own details when available.
#
# + sourceError - The error raised by the xlsx module while reading/binding rows
# + return - A typed validation error describing the failure
function toExpenseValidationError(xlsx:Error sourceError) returns ExpenseValidationError {
    xlsx:ErrorDetails errorDetails = sourceError.detail();
    string? fieldName = errorDetails?.fieldName;
    int? rowNumber = errorDetails?.rowNumber;
    return error ExpenseValidationError(sourceError.message(),
            rowNumber = rowNumber ?: 0,
            column = fieldName ?: "",
            reason = sourceError.message());
}

# Result of scanning the sheet for a trailing TOTAL row.
type DataRowScanResult record {|
    int dataRowCount;
    boolean hasTotalRow;
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
# + return - The computed total amount, or a typed validation error if the cell cannot be read
function readSheetTotalAmount(xlsx:Sheet sheet, int totalRowIndex) returns decimal|ExpenseValidationError {
    decimal|xlsx:Error sheetTotalResult = sheet.getCell(totalRowIndex, AMOUNT_USD_COLUMN_INDEX);
    if sheetTotalResult is xlsx:Error {
        return error ExpenseValidationError("Unable to read TOTAL row amount",
                rowNumber = totalRowIndex + 1, column = "Amount (USD)",
                reason = string `The TOTAL row's Amount (USD) cell could not be read as a number: ${sheetTotalResult.message()}`);
    }
    return sheetTotalResult;
}

# Processes an uploaded XLSX workbook (as raw bytes) entirely in memory and produces a validated summary.
#
# A trailing TOTAL row (Employee ID cell reading 'TOTAL') is detected and excluded from the parsed
# entries; when present, its Amount (USD) formula cell is read as its computed value and checked
# against the sum of the parsed amounts.
#
# + workbookBytes - The raw bytes of the uploaded .xlsx workbook
# + return - The upload summary on success, a typed validation error, or a typed TOTAL mismatch error
function processExpenseWorkbook(byte[] workbookBytes) returns ExpenseUploadSummary|ExpenseValidationError|ExpenseTotalMismatchError {
    xlsx:Workbook|xlsx:Error workbook = xlsx:fromBytes(workbookBytes);
    if workbook is xlsx:Error {
        return error ExpenseValidationError("Unable to read workbook",
                rowNumber = 0, column = "", reason = string `The uploaded file is not a valid .xlsx workbook: ${workbook.message()}`);
    }

    xlsx:Sheet|xlsx:Error sheet = workbook.getSheet(EXPENSE_SHEET_NAME);
    if sheet is xlsx:Error {
        error? closeResult = workbook.close();
        return error ExpenseValidationError("Sheet not found",
                rowNumber = 0, column = "",
                reason = string `Workbook does not contain a sheet named '${EXPENSE_SHEET_NAME}'.`);
    }

    string|xlsx:Error reportingPeriodResult = sheet.getCell(REPORTING_PERIOD_ROW_INDEX, REPORTING_PERIOD_COLUMN_INDEX);
    if reportingPeriodResult is xlsx:Error {
        error? closeResult = workbook.close();
        return error ExpenseValidationError("Reporting period cell is missing",
                rowNumber = REPORTING_PERIOD_ROW_INDEX + 1, column = "B",
                reason = string `Cell B2 could not be read: ${reportingPeriodResult.message()}`);
    }
    string reportingPeriod = reportingPeriodResult;

    DataRowScanResult|xlsx:Error dataRowScanResult = resolveDataRowCount(sheet);
    if dataRowScanResult is xlsx:Error {
        error? closeResult = workbook.close();
        return toExpenseValidationError(dataRowScanResult);
    }
    int dataRowCount = dataRowScanResult.dataRowCount;
    boolean hasTotalRow = dataRowScanResult.hasTotalRow;

    ExpenseEntry[]|xlsx:Error boundEntriesResult = sheet.getRows({
        headerRowIndex: HEADER_ROW_INDEX,
        caseInsensitiveHeaders: true,
        rowCount: dataRowCount
    });
    if boundEntriesResult is xlsx:Error {
        error? closeResult = workbook.close();
        return toExpenseValidationError(boundEntriesResult);
    }
    ExpenseEntry[] boundEntries = boundEntriesResult;

    decimal|ExpenseValidationError|() sheetTotalResult = ();
    if hasTotalRow {
        int totalRowIndex = DATA_START_ROW_INDEX + dataRowCount;
        sheetTotalResult = readSheetTotalAmount(sheet, totalRowIndex);
    }

    error? closeResult = workbook.close();

    if sheetTotalResult is ExpenseValidationError {
        return sheetTotalResult;
    }
    decimal? sheetTotalAmountUsd = sheetTotalResult;

    ExpenseEntry[] expenseEntries = [];
    foreach int entryIndex in 0 ..< boundEntries.length() {
        int rowNumber = DATA_START_ROW_INDEX + 1 + entryIndex;
        ExpenseEntry|ExpenseValidationError validatedEntry = validateExpenseEntry(boundEntries[entryIndex], rowNumber);
        if validatedEntry is ExpenseValidationError {
            return validatedEntry;
        }
        expenseEntries.push(validatedEntry);
    }

    decimal totalAmountUsd = 0d;
    map<decimal> perDepartment = {};
    foreach ExpenseEntry expenseEntry in expenseEntries {
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

    return {
        reportingPeriod,
        totalEntries: expenseEntries.length(),
        totalAmountUsd,
        perDepartment
    };
}
