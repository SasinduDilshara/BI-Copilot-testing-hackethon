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

// Locates the line number of the row that fails to bind into an OrderLine, by matching the raw
// header and data rows read from the same file. Returns 0 if no such row can be identified.
function findMalformedLine(string[][] rawRows) returns int {
    if rawRows.length() == 0 {
        return 0;
    }
    string[] headerRow = rawRows[0];
    int orderIdIndex = headerRow.indexOf("Order ID") ?: -1;
    int skuIndex = headerRow.indexOf("SKU") ?: -1;
    int qtyIndex = headerRow.indexOf("Quantity") ?: -1;
    int unitPriceIndex = headerRow.indexOf("Unit Price") ?: -1;

    foreach int i in 1 ..< rawRows.length() {
        string[] dataRow = rawRows[i];
        OrderLine|error orderLine = buildOrderLineFromRawRow(dataRow, orderIdIndex, skuIndex, qtyIndex, unitPriceIndex);
        if orderLine is error {
            return i + 1;
        }
    }
    return 0;
}

// Attempts to build an OrderLine from a raw CSV row using the given column indexes.
// Used only to pinpoint which line failed conversion when a typed getCsv bind fails.
function buildOrderLineFromRawRow(string[] dataRow, int orderIdIndex, int skuIndex, int qtyIndex, int unitPriceIndex) returns OrderLine|error {
    if orderIdIndex < 0 || skuIndex < 0 || qtyIndex < 0 || unitPriceIndex < 0 {
        return error("order file header is missing one or more expected columns");
    }
    return {
        orderId: dataRow[orderIdIndex],
        sku: dataRow[skuIndex],
        qty: check int:fromString(dataRow[qtyIndex]),
        unitPrice: check decimal:fromString(dataRow[unitPriceIndex])
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
