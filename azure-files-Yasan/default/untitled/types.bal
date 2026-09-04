# Supported invoice currencies.
public enum Currency {
    USD,
    EUR,
    GBP
}

# A single validated invoice line item bound from a CSV data row.
#
# + invoiceId - Invoice identifier from the 'Invoice ID' column
# + vendorId - Vendor identifier from the 'Vendor ID' column
# + lineNo - Line number from the 'Line No' column
# + description - Free text description from the 'Description' column
# + quantity - Quantity from the 'Quantity' column, must be greater than 0
# + unitPrice - Unit price from the 'Unit Price' column
# + amount - Total amount from the 'Amount' column, must equal quantity * unitPrice within 0.01
# + currency - Currency code from the 'Currency' column
public type InvoiceLine record {|
    string invoiceId;
    string vendorId;
    int lineNo;
    string description;
    int quantity;
    decimal unitPrice;
    decimal amount;
    Currency currency;
|};

# Structured error detail identifying the exact cause of a failed invoice file.
#
# + fileName - Name of the invoice file that failed processing
# + lineNo - The failing line number, or 0 when the failure is not tied to a specific line
# + reason - Human readable reason describing why processing failed
public type InvoiceFileError record {|
    string fileName;
    int lineNo;
    string reason;
|};

# One-line typed summary logged for each successfully processed invoice file.
#
# + fileName - Name of the invoice file that was processed
# + lineCount - Number of invoice lines processed in the file
# + totalAmountByCurrency - Total amount grouped by currency
public type InvoiceFileSummary record {|
    string fileName;
    int lineCount;
    map<decimal> totalAmountByCurrency;
|};

# Result of binding and validating all rows in an invoice CSV file.
#
# + lines - Successfully bound and validated invoice lines
# + fileError - Populated when binding or validation failed for any line
public type InvoiceParseResult record {|
    InvoiceLine[] lines;
    InvoiceFileError fileError?;
|};
