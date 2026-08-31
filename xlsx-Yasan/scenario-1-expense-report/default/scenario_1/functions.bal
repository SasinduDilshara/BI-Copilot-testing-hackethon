import ballerina/xlsx;

const string EXPENSE_SHEET_NAME = "Expense Report";
const int REPORTING_PERIOD_ROW_INDEX = 1;
const int REPORTING_PERIOD_COLUMN_INDEX = 1;
const int HEADER_ROW_INDEX = 2;
const decimal MIN_AMOUNT_USD = 0d;
const decimal MAX_AMOUNT_USD = 10000d;

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

# Processes an uploaded XLSX workbook (as raw bytes) entirely in memory and produces a validated summary.
#
# + workbookBytes - The raw bytes of the uploaded .xlsx workbook
# + return - The upload summary on success, or a typed validation error identifying the failing row/column
function processExpenseWorkbook(byte[] workbookBytes) returns ExpenseUploadSummary|ExpenseValidationError {
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

    ExpenseEntry[]|xlsx:Error boundEntriesResult = sheet.getRows({headerRowIndex: HEADER_ROW_INDEX});
    if boundEntriesResult is xlsx:Error {
        error? closeResult = workbook.close();
        return toExpenseValidationError(boundEntriesResult);
    }
    ExpenseEntry[] boundEntries = boundEntriesResult;

    error? closeResult = workbook.close();

    ExpenseEntry[] expenseEntries = [];
    foreach int entryIndex in 0 ..< boundEntries.length() {
        int rowNumber = HEADER_ROW_INDEX + 2 + entryIndex;
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

    return {
        reportingPeriod,
        totalEntries: expenseEntries.length(),
        totalAmountUsd,
        perDepartment
    };
}
