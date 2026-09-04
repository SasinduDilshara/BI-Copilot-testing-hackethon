// Maps a raw CSV row (matched by header name) into the canonical OrderLine record.
function toOrderLine(OrderCsvRow csvRow) returns OrderLine|error => {
    orderId: csvRow.'Order\ ID,
    sku: csvRow.SKU,
    qty: check int:fromString(csvRow.Quantity),
    unitPrice: check decimal:fromString(csvRow.'Unit\ Price)
};
