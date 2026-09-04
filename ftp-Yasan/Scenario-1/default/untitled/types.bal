// Canonical order line record used throughout the program.
public type OrderLine record {|
    string orderId;
    string sku;
    int qty;
    decimal unitPrice;
|};

// Intermediate record used only to bind CSV rows, since the source CSV headers
// ('Order ID', 'SKU', 'Quantity', 'Unit Price') do not match the OrderLine field names.
type OrderCsvRow record {|
    string 'Order\ ID;
    string SKU;
    string Quantity;
    string 'Unit\ Price;
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
