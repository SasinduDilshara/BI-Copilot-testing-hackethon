// Expected CSV header columns, in order, for an orders file.
final string[] & readonly expectedOrderHeader = ["Order ID", "SKU", "Quantity", "Unit Price"];

// Binds a single raw CSV row (excluding the header) to an OrderLine record.
// Returns an error when the row cannot bind, e.g. wrong column count or non-numeric quantity/price.
function bindOrderLine(string[] row) returns OrderLine|error {
    if row.length() != expectedOrderHeader.length() {
        return error(string `expected ${expectedOrderHeader.length()} columns but found ${row.length()}`);
    }
    string orderId = row[0];
    string sku = row[1];
    int qty = check int:fromString(row[2]);
    decimal unitPrice = check decimal:fromString(row[3]);
    OrderLine orderLine = {orderId, sku, qty, unitPrice};
    return orderLine;
}

// Validates business rules for an order line. Returns an error describing the violation when invalid.
function validateOrderLine(OrderLine orderLine) returns error? {
    if orderLine.qty <= 0 {
        return error(string `invalid quantity ${orderLine.qty} for order ${orderLine.orderId}`);
    }
    if orderLine.unitPrice < 0d {
        return error(string `invalid unit price ${orderLine.unitPrice} for order ${orderLine.orderId}`);
    }
}

// Computes the order count, per-sku quantity map, and grand total for a set of validated order lines.
function summarizeOrderLines(string fileName, OrderLine[] orderLines) returns OrderSummary {
    map<int> quantityBySku = {};
    decimal grandTotal = 0d;
    foreach OrderLine orderLine in orderLines {
        if quantityBySku.hasKey(orderLine.sku) {
            int existingQty = quantityBySku.get(orderLine.sku);
            quantityBySku[orderLine.sku] = existingQty + orderLine.qty;
        } else {
            quantityBySku[orderLine.sku] = orderLine.qty;
        }
        grandTotal += <decimal>orderLine.qty * orderLine.unitPrice;
    }
    OrderSummary summary = {
        fileName,
        orderCount: orderLines.length(),
        quantityBySku,
        grandTotal
    };
    return summary;
}
