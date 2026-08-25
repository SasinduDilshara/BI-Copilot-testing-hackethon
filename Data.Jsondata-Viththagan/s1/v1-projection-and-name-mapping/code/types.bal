import ballerina/data.jsondata;

// Represents a single line item within an order.
type LineItem record {|
    @jsondata:Name {value: "sku"}
    string sku;

    @jsondata:Name {value: "quantity"}
    int quantity;

    @jsondata:Name {value: "unit_price"}
    decimal unitPrice;
|};

// Represents the partner order feed payload. Only the fields we model are
// bound - all other metadata fields present in the incoming JSON are ignored
// since this is a closed record.
type OrderFeed record {|
    @jsondata:Name {value: "order_id"}
    string orderId;

    @jsondata:Name {value: "customer_email"}
    string customerEmail;

    @jsondata:Name {value: "line_items"}
    LineItem[] lineItems;

    @jsondata:Name {value: "placed_at"}
    string placedAt;
|};

// Response returned once an order feed payload has been accepted and mapped.
type OrderFeedAck record {|
    string orderId;
    string status;
|};

// Error payload returned when the incoming order feed cannot be parsed/mapped.
type OrderFeedError record {|
    string message;
|};
