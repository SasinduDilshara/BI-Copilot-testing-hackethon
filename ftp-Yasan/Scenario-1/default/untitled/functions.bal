import ballerina/log;

// Checks whether a file name matches the expected order file pattern.
function isOrderFile(string fileName) returns boolean => ORDER_FILE_PATTERN.isFullMatch(fileName);

// Validates a single order line: qty must be greater than 0 and unitPrice must be at least 0.
function isValidOrderLine(OrderLine orderLine) returns boolean => orderLine.qty > 0 && orderLine.unitPrice >= 0d;

// Validates every already-bound order line of a file. Returns the lines only when all are valid.
// Logs the file name and the failing line number for any line that breaks a business rule.
function validateOrderFile(string fileName, OrderLine[] orderLines) returns FileValidationResult {
    boolean allValid = true;
    foreach int i in 0 ..< orderLines.length() {
        OrderLine orderLine = orderLines[i];
        if !isValidOrderLine(orderLine) {
            log:printError(string `Invalid order line in file ${fileName} at line ${i + 2}: ${orderLine.toString()}`);
            allValid = false;
        }
    }
    return {valid: allValid, lines: orderLines};
}

// Locates the true 1-based physical line number of the row that fails to bind into an OrderLine.
// getCsv into string[][] returns only the data rows (the header row is consumed, not included),
// so rawRows[0] is physical line 2 (the header itself is physical line 1). Columns are matched
// by their fixed position, since there is no header row here to look them up by name.
// Returns 0 if no such row can be identified.
function findMalformedLine(string[][] rawRows) returns int {
    foreach int i in 0 ..< rawRows.length() {
        OrderLine|error orderLine = buildOrderLineFromRawRow(rawRows[i]);
        if orderLine is error {
            return i + 2;
        }
    }
    return 0;
}

// Attempts to build an OrderLine from a raw CSV data row, assuming the fixed column order
// Order ID, SKU, Quantity, Unit Price. Used only to pinpoint which line failed conversion
// when a typed getCsv bind fails.
function buildOrderLineFromRawRow(string[] dataRow) returns OrderLine|error {
    if dataRow.length() < 4 {
        return error("order row does not have the expected number of columns");
    }
    return {
        orderId: dataRow[0],
        sku: dataRow[1],
        qty: check int:fromString(dataRow[2]),
        unitPrice: check decimal:fromString(dataRow[3])
    };
}

// Builds the per-file summary: order count, per-sku quantity map, and grand total amount.
function buildOrderFileSummary(OrderLine[] orderLines) returns OrderFileSummary {
    map<int> quantityBySku = {};
    decimal grandTotal = 0d;
    foreach OrderLine orderLine in orderLines {
        int currentQty = quantityBySku.hasKey(orderLine.sku) ? quantityBySku.get(orderLine.sku) : 0;
        quantityBySku[orderLine.sku] = currentQty + orderLine.qty;
        grandTotal += <decimal>orderLine.qty * orderLine.unitPrice;
    }
    return {
        orderCount: orderLines.length(),
        quantityBySku,
        grandTotal
    };
}
