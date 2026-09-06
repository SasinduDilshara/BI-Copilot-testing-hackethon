// Represents a single order line item bound from a row of the incoming orders CSV file.
type OrderLine record {|
    string orderId;
    string sku;
    int qty;
    decimal unitPrice;
|};

// Summary computed for a single processed orders file.
type OrderSummary record {|
    string fileName;
    int orderCount;
    map<int> quantityBySku;
    decimal grandTotal;
|};
