// Represents an order record fetched from the database.
public type Order record {|
    int orderId;
    string customerName;
    string status;
    string orderDate;
    decimal amount;
|};
