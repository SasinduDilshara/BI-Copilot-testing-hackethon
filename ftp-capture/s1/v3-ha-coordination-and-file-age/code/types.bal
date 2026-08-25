// Strongly typed representation of a single partner order row parsed from an
// incoming CSV file.
public type Order record {|
    string orderId;
    string customerId;
    string productCode;
    int quantity;
    decimal unitPrice;
    string orderDate;
|};

// Strongly typed representation of a single partner return row parsed from an
// incoming CSV file.
public type Return record {|
    string returnId;
    string orderId;
    string productCode;
    int quantity;
    string reason;
    string returnDate;
|};
