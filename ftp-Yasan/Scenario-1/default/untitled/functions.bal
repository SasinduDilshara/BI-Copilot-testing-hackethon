// Checks whether a file name matches the expected order file pattern.
function isOrderFile(string fileName) returns boolean => ORDER_FILE_PATTERN.isFullMatch(fileName);

// Validates a single order line: qty must be greater than 0 and unitPrice must be at least 0.
function isValidOrderLine(OrderLine orderLine) returns boolean => orderLine.qty > 0 && orderLine.unitPrice >= 0d;

// Folds one valid order line into the running aggregate, updating the order count,
// the per-sku quantity map, and the grand total amount in place. This is the only state
// kept in memory while streaming through a file; individual lines are never collected into a list.
function accumulateOrderLine(OrderFileAggregate aggregate, OrderLine orderLine) {
    aggregate.orderCount += 1;
    int currentQty = aggregate.quantityBySku.hasKey(orderLine.sku) ? aggregate.quantityBySku.get(orderLine.sku) : 0;
    aggregate.quantityBySku[orderLine.sku] = currentQty + orderLine.qty;
    aggregate.grandTotal += <decimal>orderLine.qty * orderLine.unitPrice;
}

// Builds the per-file summary from the final accumulated totals.
function toOrderFileSummary(OrderFileAggregate aggregate) returns OrderFileSummary => {
    orderCount: aggregate.orderCount,
    quantityBySku: aggregate.quantityBySku,
    grandTotal: aggregate.grandTotal
};
