// Represents a customer associated with an order.
public type Customer record {|
    int customerId;
    string firstName;
    string lastName;
    string email;
    string phone?;
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

// Represents the core order record as stored in the database.
public type Order record {|
    int orderId;
    int customerId;
    string orderStatus;
    decimal totalAmount;
    string createdAt;
|};

// Represents the full order details returned by the API, including
// customer information and line items.
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
