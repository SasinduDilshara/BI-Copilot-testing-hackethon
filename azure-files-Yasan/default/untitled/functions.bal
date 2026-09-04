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

# Binds and validates every data row of an invoice CSV file, streamed row by row so that a
# malformed row (for example a non-numeric quantity or an unsupported currency) surfaces as a
# stream element error instead of aborting dispatch to this handler.
#
# + fileName - Name of the invoice file being processed, used for error reporting
# + invoiceLineStream - Invoice lines bound natively from the CSV data rows, row by row
# + return - The parse result, containing either the validated lines or a structured file error,
# or an error when reading the underlying stream itself fails
function parseInvoiceFile(string fileName, stream<InvoiceLine, error?> invoiceLineStream) returns InvoiceParseResult|error {
    InvoiceLine[] invoiceLines = [];
    int csvLineNo = 1;

    while true {
        csvLineNo += 1;
        record {|InvoiceLine value;|}|error? nextRow = invoiceLineStream.next();

        if nextRow is () {
            break;
        }

        if nextRow is error {
            InvoiceFileError fileError = {fileName, lineNo: csvLineNo, reason: string `binding failed: ${nextRow.message()}`};
            return {lines: [], fileError};
        }

        InvoiceLine invoiceLine = nextRow.value;
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
