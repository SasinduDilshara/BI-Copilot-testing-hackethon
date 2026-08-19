import ballerina/time;

// Represents a customer associated with an order. Name, email, and phone
// columns are nullable in the production schema, so they are modelled as
// nilable fields rather than defaulting or failing on NULL.
public type Customer record {|
    int customerId;
    string? firstName;
    string? lastName;
    string? email;
    string? phone;
|};

// Represents a single line item within an order.
public type OrderItem record {|
    int orderItemId;
    int productId;
    string productName;
    int quantity;
    decimal unitPrice;
    decimal lineTotal;
|};

// Represents the core order record as stored in the database. `createdAt` is
// bound as a `time:Civil` since that is how the SQL module maps MySQL
// TIMESTAMP/DATETIME columns.
public type Order record {|
    int orderId;
    int customerId;
    string orderStatus;
    decimal totalAmount;
    time:Civil createdAt;
|};

// Represents the full order details returned by the API, including
// customer information and line items. `createdAt` is exposed as an RFC 3339
// string for a stable, strongly typed JSON representation. `lineItems` is
// always present as an array (empty when the order has no line items).
public type OrderDetails record {|
    int orderId;
    string orderStatus;
    decimal totalAmount;
    string createdAt;
    Customer customer;
    OrderItem[] lineItems;
|};

// Represents an error response body.
public type ErrorDetails record {|
    string message;
    string timestamp;
    string path;
|};
