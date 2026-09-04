import ballerina/data.csv;

// Canonical order line record used throughout the program.
// The @csv:Name annotations map each field to its differently-named CSV header,
// so ftp:Client's getCsv (which binds CSV content through ballerina/data.csv) can
// bind directly into this record without any intermediate type or manual mapping.
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

// Running aggregate accumulated while streaming through an order file's rows, one at a time.
// Only these totals are kept in memory; individual order lines are never materialized into a list.
type OrderFileAggregate record {|
    int orderCount = 0;
    map<int> quantityBySku = {};
    decimal grandTotal = 0d;
|};

// Per-file summary written back to the server as JSON.
public type OrderFileSummary record {|
    int orderCount;
    map<int> quantityBySku;
    decimal grandTotal;
|};
