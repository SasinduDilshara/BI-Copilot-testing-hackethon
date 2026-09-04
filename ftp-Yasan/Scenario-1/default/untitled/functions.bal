import ballerina/log;

// Checks whether a file name matches the expected order file pattern.
function isOrderFile(string fileName) returns boolean => ORDER_FILE_PATTERN.isFullMatch(fileName);

// Validates a single order line: qty must be greater than 0 and unitPrice must be at least 0.
function isValidOrderLine(OrderLine orderLine) returns boolean => orderLine.qty > 0 && orderLine.unitPrice >= 0d;

// Validates every line of a file. Returns the parsed lines only when all lines are valid.
// Logs the file name and the failing line number for any invalid line encountered.
function validateOrderFile(string fileName, OrderCsvRow[] csvRows) returns FileValidationResult|error {
    OrderLine[] orderLines = [];
    boolean allValid = true;
    foreach int i in 0 ..< csvRows.length() {
        OrderLine orderLine = check toOrderLine(csvRows[i]);
        boolean lineValid = isValidOrderLine(orderLine);
        if !lineValid {
            log:printError(string `Invalid order line in file ${fileName} at line ${i + 2}: ${orderLine.toString()}`);
            allValid = false;
            continue;
        }
        orderLines.push(orderLine);
    }
    return {valid: allValid, lines: orderLines};
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
