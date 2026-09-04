const string[] EXPECTED_HEADER = ["Invoice ID", "Vendor ID", "Line No", "Description", "Quantity", "Unit Price", "Amount", "Currency"];

# Converts a header column value into the matching `Currency` enum member.
#
# + value - Raw currency text read from the 'Currency' column
# + return - The matching `Currency` value, or an error when the value is not a supported currency
function toCurrency(string value) returns Currency|error {
    match value {
        "USD" => {
            return USD;
        }
        "EUR" => {
            return EUR;
        }
        "GBP" => {
            return GBP;
        }
        _ => {
            return error(string `unsupported currency '${value}'`);
        }
    }
}

# Binds a single CSV data row into an `InvoiceLine`, given the header-to-index mapping.
#
# + row - Raw CSV row values
# + columnIndexes - Map of expected header name to its column index in the row
# + return - The bound `InvoiceLine`, or an error describing why binding failed
function bindInvoiceLine(string[] row, map<int> columnIndexes) returns InvoiceLine|error {
    int invoiceIdIndex = columnIndexes.get("Invoice ID");
    int vendorIdIndex = columnIndexes.get("Vendor ID");
    int lineNoIndex = columnIndexes.get("Line No");
    int descriptionIndex = columnIndexes.get("Description");
    int quantityIndex = columnIndexes.get("Quantity");
    int unitPriceIndex = columnIndexes.get("Unit Price");
    int amountIndex = columnIndexes.get("Amount");
    int currencyIndex = columnIndexes.get("Currency");

    int lineNo = check int:fromString(row[lineNoIndex]);
    int quantity = check int:fromString(row[quantityIndex]);
    decimal unitPrice = check decimal:fromString(row[unitPriceIndex]);
    decimal amount = check decimal:fromString(row[amountIndex]);
    Currency currency = check toCurrency(row[currencyIndex]);

    InvoiceLine invoiceLine = {
        invoiceId: row[invoiceIdIndex],
        vendorId: row[vendorIdIndex],
        lineNo,
        description: row[descriptionIndex],
        quantity,
        unitPrice,
        amount,
        currency
    };
    return invoiceLine;
}

# Validates a bound invoice line against the accounts-payable business rules.
#
# + invoiceLine - The invoice line to validate
# + return - An error describing the failed rule, or `()` when the line is valid
function validateInvoiceLine(InvoiceLine invoiceLine) returns error? {
    if invoiceLine.quantity <= 0 {
        return error(string `quantity must be greater than 0, found ${invoiceLine.quantity}`);
    }
    decimal expectedAmount = invoiceLine.quantity * invoiceLine.unitPrice;
    decimal difference = expectedAmount - invoiceLine.amount;
    if difference < 0d {
        difference = -difference;
    }
    if difference > 0.01d {
        return error(string `amount ${invoiceLine.amount} does not equal quantity * unitPrice (${expectedAmount}) within 0.01`);
    }
    return;
}

# Builds a map of expected header name to column index from the file's header row.
#
# + headerRow - The first row of the CSV file
# + return - Map of header name to column index, or an error when the header does not match exactly
function resolveColumnIndexes(string[] headerRow) returns map<int>|error {
    if headerRow.length() != EXPECTED_HEADER.length() {
        return error(string `expected ${EXPECTED_HEADER.length()} columns, found ${headerRow.length()}`);
    }
    map<int> columnIndexes = {};
    foreach string expectedColumn in EXPECTED_HEADER {
        int? index = headerRow.indexOf(expectedColumn);
        if index is () {
            return error(string `missing expected column '${expectedColumn}'`);
        }
        columnIndexes[expectedColumn] = index;
    }
    return columnIndexes;
}

# Parses and validates every data row of an invoice CSV file.
#
# + fileName - Name of the invoice file being parsed, used for error reporting
# + content - Raw CSV rows, including the header row as the first element
# + return - The parse result, containing either the bound and validated lines, or a structured file error
function parseInvoiceFile(string fileName, string[][] content) returns InvoiceParseResult {
    if content.length() == 0 {
        InvoiceFileError fileError = {fileName, lineNo: 0, reason: "file is empty, missing header row"};
        return {lines: [], fileError};
    }

    string[] headerRow = content[0];
    map<int>|error columnIndexes = resolveColumnIndexes(headerRow);
    if columnIndexes is error {
        InvoiceFileError fileError = {fileName, lineNo: 0, reason: columnIndexes.message()};
        return {lines: [], fileError};
    }

    InvoiceLine[] invoiceLines = [];
    foreach int rowIndex in 1 ..< content.length() {
        string[] row = content[rowIndex];
        int csvLineNo = rowIndex + 1;

        InvoiceLine|error invoiceLine = bindInvoiceLine(row, columnIndexes);
        if invoiceLine is error {
            InvoiceFileError fileError = {fileName, lineNo: csvLineNo, reason: string `binding failed: ${invoiceLine.message()}`};
            return {lines: [], fileError};
        }

        error? validationResult = validateInvoiceLine(invoiceLine);
        if validationResult is error {
            InvoiceFileError fileError = {fileName, lineNo: csvLineNo, reason: string `validation failed: ${validationResult.message()}`};
            return {lines: [], fileError};
        }

        invoiceLines.push(invoiceLine);
    }

    return {lines: invoiceLines};
}

# Builds the one-line typed summary for a successfully processed invoice file.
#
# + fileName - Name of the invoice file that was processed
# + invoiceLines - The validated invoice lines contained in the file
# + return - A summary with the line count and total amount grouped by currency
function buildInvoiceSummary(string fileName, InvoiceLine[] invoiceLines) returns InvoiceFileSummary {
    map<decimal> totalAmountByCurrency = {};
    foreach InvoiceLine invoiceLine in invoiceLines {
        string currencyKey = invoiceLine.currency;
        decimal currentTotal = totalAmountByCurrency[currencyKey] ?: 0d;
        totalAmountByCurrency[currencyKey] = currentTotal + invoiceLine.amount;
    }
    return {
        fileName,
        lineCount: invoiceLines.length(),
        totalAmountByCurrency
    };
}
