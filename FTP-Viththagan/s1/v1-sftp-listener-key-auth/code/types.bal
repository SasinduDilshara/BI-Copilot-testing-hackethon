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
