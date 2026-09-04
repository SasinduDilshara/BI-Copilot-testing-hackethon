# Validates a bound OrderLine according to the business rules.
# qty must be greater than zero and unitPrice must not be negative.
#
# + orderLine - The order line to validate
# + return - An error describing the validation failure, or nil if valid
function validateOrderLine(OrderLine orderLine) returns error? {
    if orderLine.qty <= 0 {
        return error("invalid quantity: " + orderLine.qty.toString());
    }
    if orderLine.unitPrice < 0d {
        return error("invalid unit price: " + orderLine.unitPrice.toString());
    }
    return ();
}

# Computes the order summary for a set of valid order lines belonging to a single file.
#
# + fileName - The name of the source file
# + orderLines - The valid order lines parsed from the file
# + return - The computed order summary
function computeOrderSummary(string fileName, OrderLine[] orderLines) returns OrderSummary {
    map<int> quantityBySku = {};
    decimal grandTotal = 0d;
    foreach OrderLine orderLine in orderLines {
        int existingQty = quantityBySku.hasKey(orderLine.sku) ? quantityBySku.get(orderLine.sku) : 0;
        quantityBySku[orderLine.sku] = existingQty + orderLine.qty;
        grandTotal += <decimal>orderLine.qty * orderLine.unitPrice;
    }
    return {
        fileName: fileName,
        orderCount: orderLines.length(),
        quantityBySku: quantityBySku,
        grandTotal: grandTotal
    };
}
