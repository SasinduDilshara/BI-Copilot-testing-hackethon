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

// Result of validating a single order file.
type FileValidationResult record {|
    boolean valid;
    OrderLine[] lines;
|};

// Per-file summary written back to the server as JSON.
public type OrderFileSummary record {|
    int orderCount;
    map<int> quantityBySku;
    decimal grandTotal;
|};
