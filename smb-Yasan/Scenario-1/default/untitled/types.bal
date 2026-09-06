import ballerina/data.csv;

// Represents a single validated order line read from an incoming orders CSV file.
// The CSV header uses 'Order ID', 'SKU', 'Quantity', 'Unit Price' column names.
public type OrderLine record {|
    @csv:Name {value: "Order ID"}
    string orderId;
    @csv:Name {value: "SKU"}
    string sku;
    @csv:Name {value: "Quantity"}
    int qty;
    @csv:Name {value: "Unit Price"}
    decimal unitPrice;
|};

// Per-file processing summary written to /processed/<original-name>.summary.json.
public type OrderFileSummary record {|
    int orderCount;
    map<int> quantityBySku;
    decimal grandTotal;
|};
