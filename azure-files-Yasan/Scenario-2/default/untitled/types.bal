import ballerina/data.csv;

// Represents a single order row parsed from an incoming order CSV file.
// Field names are bound from the CSV header row: 'Order ID', 'SKU', 'Qty'.
type Order record {
    @csv:Name {value: "Order ID"}
    string orderId;
    string sku;
    @csv:Name {value: "Qty"}
    int qty;
};
