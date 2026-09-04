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

# Validates every already-bound invoice line of an invoice CSV file.
#
# + fileName - Name of the invoice file being validated, used for error reporting
# + invoiceLines - Invoice lines bound natively from the CSV data rows
# + return - The parse result, containing either the validated lines, or a structured file error
function parseInvoiceFile(string fileName, InvoiceLine[] invoiceLines) returns InvoiceParseResult {
    foreach int rowIndex in 0 ..< invoiceLines.length() {
        InvoiceLine invoiceLine = invoiceLines[rowIndex];
        int csvLineNo = rowIndex + 2;

        error? validationResult = validateInvoiceLine(invoiceLine);
        if validationResult is error {
            InvoiceFileError fileError = {fileName, lineNo: csvLineNo, reason: string `validation failed: ${validationResult.message()}`};
            return {lines: [], fileError};
        }
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
