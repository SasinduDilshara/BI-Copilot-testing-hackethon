// Represents a known order that can be tracked.
public type Order record {|
    string orderId;
    string status;
    Location courierLocation;
    string estimatedArrival;
|};

// Represents a geo-location of the courier.
public type Location record {|
    decimal latitude;
    decimal longitude;
|};

// Represents an update message pushed down to the customer over the WebSocket connection.
public type OrderUpdate record {|
    string orderId;
    string status;
    Location courierLocation;
    string estimatedArrival;
    string updatedAt;
|};
