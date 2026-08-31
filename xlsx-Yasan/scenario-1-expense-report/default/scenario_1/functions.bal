import ballerina/lang.regexp;
import ballerina/time;
import ballerina/xlsx;

const string EXPENSE_SHEET_NAME = "Expense Report";
const int HEADER_ROW_NUMBER = 3;
const int DATA_START_ROW_NUMBER = 4;
const decimal MIN_AMOUNT_USD = 0d;
const decimal MAX_AMOUNT_USD = 10000d;

final string[] EXPECTED_HEADERS = [
    "Employee ID",
    "Employee Name",
    "Department",
    "Expense Date",
    "Category",
    "Amount (USD)",
    "Receipt Attached"
];

# Extracts the reporting period value from cell B2 (row 2, second column) of the raw sheet rows.
#
# + rawRows - All physical rows of the sheet as raw string grids
# + return - The reporting period string, or a validation error if the cell is missing
function extractReportingPeriod(string[][] rawRows) returns string|ExpenseValidationError {
    if rawRows.length() < 2 {
        return error ExpenseValidationError("Reporting period row is missing",
                rowNumber = 2, column = "B", reason = "Sheet does not contain a row 2 with the reporting period.");
    }
    string[] periodRow = rawRows[1];
    if periodRow.length() < 2 {
        return error ExpenseValidationError("Reporting period cell is missing",
                rowNumber = 2, column = "B", reason = "Cell B2 is empty or missing.");
    }
    string reportingPeriod = periodRow[1].trim();
    if reportingPeriod.length() == 0 {
        return error ExpenseValidationError("Reporting period cell is empty",
                rowNumber = 2, column = "B", reason = "Cell B2 is empty.");
    }
    return reportingPeriod;
}

# Validates that row 3 contains exactly the expected column headers.
#
# + rawRows - All physical rows of the sheet as raw string grids
# + return - An error if the header row is missing or does not match the expected layout
function validateHeaderRow(string[][] rawRows) returns ExpenseValidationError? {
    if rawRows.length() < HEADER_ROW_NUMBER {
        return error ExpenseValidationError("Header row is missing",
                rowNumber = HEADER_ROW_NUMBER, column = "A", reason = "Sheet does not contain a header row on row 3.");
    }
    string[] headerRow = rawRows[HEADER_ROW_NUMBER - 1];
    foreach int columnIndex in 0 ..< EXPECTED_HEADERS.length() {
        string expectedHeader = EXPECTED_HEADERS[columnIndex];
        string actualHeader = columnIndex < headerRow.length() ? headerRow[columnIndex].trim() : "";
        if actualHeader != expectedHeader {
            return error ExpenseValidationError("Unexpected column header",
                    rowNumber = HEADER_ROW_NUMBER,
                    column = columnToLetter(columnIndex),
                    reason = string `Expected header '${expectedHeader}' but found '${actualHeader}'.`);
        }
    }
    return ();
}

# Converts a 0-based column index to a spreadsheet column letter (0 -> A, 1 -> B, ...).
#
# + columnIndex - 0-based column index
# + return - The spreadsheet column letter
function columnToLetter(int columnIndex) returns string {
    int adjustedIndex = columnIndex;
    string result = "";
    while true {
        int remainder = adjustedIndex % 26;
        string letter = check2Letter(remainder);
        result = letter + result;
        adjustedIndex = (adjustedIndex / 26) - 1;
        if adjustedIndex < 0 {
            break;
        }
    }
    return result;
}

# Maps a 0-25 index to its corresponding uppercase letter.
#
# + letterIndex - Index between 0 and 25
# + return - The corresponding letter
function check2Letter(int letterIndex) returns string {
    string[] letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"];
    return letters[letterIndex];
}

# Parses a date string in `YYYY-MM-DD` form into a `time:Date`.
#
# + dateText - The raw date cell text
# + return - A `time:Date` value, or `()` if the text does not match the expected format
function parseExpenseDate(string dateText) returns time:Date? {
    string:RegExp datePattern = re `^([0-9]{4})-([0-9]{2})-([0-9]{2})$`;
    regexp:Groups? groups = datePattern.findGroups(dateText.trim());
    if groups is () {
        return ();
    }
    regexp:Span? yearSpan = groups[1];
    regexp:Span? monthSpan = groups[2];
    regexp:Span? daySpan = groups[3];
    if yearSpan is () || monthSpan is () || daySpan is () {
        return ();
    }
    int|error year = int:fromString(yearSpan.substring());
    int|error month = int:fromString(monthSpan.substring());
    int|error day = int:fromString(daySpan.substring());
    if year is error || month is error || day is error {
        return ();
    }
    return {year, month, day};
}

# Binds and validates a single data row into an `ExpenseEntry`.
#
# + row - The raw cell values of the data row
# + rowNumber - The 1-based spreadsheet row number, used for error reporting
# + return - A validated `ExpenseEntry`, or a typed validation error identifying the failing column/field
function bindExpenseEntry(string[] row, int rowNumber) returns ExpenseEntry|ExpenseValidationError {
    string employeeId = row.length() > 0 ? row[0].trim() : "";
    if employeeId.length() == 0 {
        return error ExpenseValidationError("Employee ID is required",
                rowNumber = rowNumber, column = "A", reason = "Employee ID must not be empty.");
    }

    string employeeName = row.length() > 1 ? row[1].trim() : "";
    if employeeName.length() == 0 {
        return error ExpenseValidationError("Employee Name is required",
                rowNumber = rowNumber, column = "B", reason = "Employee Name must not be empty.");
    }

    string department = row.length() > 2 ? row[2].trim() : "";
    if department.length() == 0 {
        return error ExpenseValidationError("Department is required",
                rowNumber = rowNumber, column = "C", reason = "Department must not be empty.");
    }

    string expenseDateText = row.length() > 3 ? row[3].trim() : "";
    time:Date? expenseDate = parseExpenseDate(expenseDateText);
    if expenseDate is () {
        return error ExpenseValidationError("Invalid expense date",
                rowNumber = rowNumber, column = "D",
                reason = string `Expense Date '${expenseDateText}' is not a valid date in YYYY-MM-DD format.`);
    }

    string categoryText = row.length() > 4 ? row[4].trim() : "";
    ExpenseCategory|ExpenseValidationError category = parseExpenseCategory(categoryText, rowNumber);
    if category is ExpenseValidationError {
        return category;
    }

    string amountText = row.length() > 5 ? row[5].trim() : "";
    decimal|error amountUsd = decimal:fromString(amountText);
    if amountUsd is error {
        return error ExpenseValidationError("Invalid amount",
                rowNumber = rowNumber, column = "F",
                reason = string `Amount (USD) '${amountText}' is not a valid decimal number.`);
    }
    if amountUsd <= MIN_AMOUNT_USD || amountUsd > MAX_AMOUNT_USD {
        return error ExpenseValidationError("Amount out of range",
                rowNumber = rowNumber, column = "F",
                reason = string `Amount (USD) ${amountUsd} must be greater than 0 and at most ${MAX_AMOUNT_USD}.`);
    }

    string receiptText = row.length() > 6 ? row[6].trim() : "";
    boolean|ExpenseValidationError receiptAttached = parseReceiptFlag(receiptText, rowNumber);
    if receiptAttached is ExpenseValidationError {
        return receiptAttached;
    }

    return {
        employeeId,
        employeeName,
        department,
        expenseDate,
        category,
        amountUsd,
        receiptAttached
    };
}

# Parses and validates the category text against the allowed `ExpenseCategory` values.
#
# + categoryText - The raw category cell text
# + rowNumber - The 1-based spreadsheet row number, used for error reporting
# + return - The parsed category, or a typed validation error
function parseExpenseCategory(string categoryText, int rowNumber) returns ExpenseCategory|ExpenseValidationError {
    match categoryText {
        "TRAVEL" => {
            return TRAVEL;
        }
        "MEALS" => {
            return MEALS;
        }
        "ACCOMMODATION" => {
            return ACCOMMODATION;
        }
        "SUPPLIES" => {
            return SUPPLIES;
        }
        "OTHER" => {
            return OTHER;
        }
        _ => {
            return error ExpenseValidationError("Invalid category",
                    rowNumber = rowNumber, column = "E",
                    reason = string `Category '${categoryText}' must be one of TRAVEL, MEALS, ACCOMMODATION, SUPPLIES, OTHER.`);
        }
    }
}

# Parses the receipt-attached flag text into a boolean.
#
# + receiptText - The raw receipt cell text
# + rowNumber - The 1-based spreadsheet row number, used for error reporting
# + return - The parsed boolean, or a typed validation error
function parseReceiptFlag(string receiptText, int rowNumber) returns boolean|ExpenseValidationError {
    string normalizedText = receiptText.toUpperAscii();
    match normalizedText {
        "TRUE"|"YES"|"Y" => {
            return true;
        }
        "FALSE"|"NO"|"N" => {
            return false;
        }
        _ => {
            return error ExpenseValidationError("Invalid receipt flag",
                    rowNumber = rowNumber, column = "G",
                    reason = string `Receipt Attached '${receiptText}' is not a valid boolean value.`);
        }
    }
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

    string[][]|xlsx:Error rawRowsResult = sheet.getRows();
    if rawRowsResult is xlsx:Error {
        error? closeResult = workbook.close();
        return error ExpenseValidationError("Unable to read sheet rows",
                rowNumber = 0, column = "", reason = string `Failed to read rows from sheet '${EXPENSE_SHEET_NAME}': ${rawRowsResult.message()}`);
    }
    string[][] rawRows = rawRowsResult;

    string|ExpenseValidationError reportingPeriodResult = extractReportingPeriod(rawRows);
    if reportingPeriodResult is ExpenseValidationError {
        error? closeResult = workbook.close();
        return reportingPeriodResult;
    }
    string reportingPeriod = reportingPeriodResult;

    ExpenseValidationError? headerValidationResult = validateHeaderRow(rawRows);
    if headerValidationResult is ExpenseValidationError {
        error? closeResult = workbook.close();
        return headerValidationResult;
    }

    ExpenseEntry[] expenseEntries = [];
    int totalRows = rawRows.length();
    foreach int rowIndex in (DATA_START_ROW_NUMBER - 1) ..< totalRows {
        string[] row = rawRows[rowIndex];
        boolean isBlankRow = row.length() == 0 || row.filter(cellValue => cellValue.trim().length() > 0).length() == 0;
        if isBlankRow {
            continue;
        }
        int rowNumber = rowIndex + 1;
        ExpenseEntry|ExpenseValidationError entryResult = bindExpenseEntry(row, rowNumber);
        if entryResult is ExpenseValidationError {
            error? closeResult = workbook.close();
            return entryResult;
        }
        expenseEntries.push(entryResult);
    }

    error? closeResult = workbook.close();

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
