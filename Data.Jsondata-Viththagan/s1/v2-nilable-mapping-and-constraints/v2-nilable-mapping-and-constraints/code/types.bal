import ballerina/constraint;
import ballerina/data.jsondata;

final string:RegExp emailPattern = re `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z][a-zA-Z]+`;

@constraint:String {
    pattern: {
        value: emailPattern,
        message: "customer_email must be a valid email address"
    }
}
type Email string;

// Represents a single line item within an order.
type LineItem record {|
    @jsondata:Name {value: "sku"}
    string sku;

    @jsondata:Name {value: "quantity"}
    @constraint:Int {
        minValue: {
            value: 0,
            message: "quantity must not be negative"
        }
    }
    int quantity;

    @jsondata:Name {value: "unit_price"}
    decimal unitPrice;
|};

// Represents the partner order feed payload. Only the fields we model are
// bound - all other metadata fields present in the incoming JSON are ignored
// since this is a closed record. discount_code may be explicitly null in the
// payload (maps to an optional field) and placed_at may be entirely absent
// (maps to a nilable field).
type OrderFeed record {|
    @jsondata:Name {value: "order_id"}
    string orderId;

    @jsondata:Name {value: "customer_email"}
    Email customerEmail;

    @jsondata:Name {value: "line_items"}
    LineItem[] lineItems;

    @jsondata:Name {value: "placed_at"}
    string? placedAt;

    @jsondata:Name {value: "discount_code"}
    string discountCode?;
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
