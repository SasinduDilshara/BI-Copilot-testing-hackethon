import ballerina/data.csv;

# Represents a single order line item parsed from an inbound orders CSV file.
# The CSV header columns are mapped to the record fields using the csv:Name annotation
# since the header names are not valid Ballerina identifiers.
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

# Summary computed for a single processed orders file.
public type OrderSummary record {|
    string fileName;
    int orderCount;
    map<int> quantityBySku;
    decimal grandTotal;
|};
