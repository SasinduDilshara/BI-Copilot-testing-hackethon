import ballerina/http;

// Command message consumed from the orders-to-fulfil queue.
public type FulfilmentCommand record {|
    string orderId;
    string customerId;
    FulfilmentItem[] items;
    string requestedAt;
    string region?;
|};

public type FulfilmentItem record {|
    string sku;
    int quantity;
|};

// Status event published to the order-status topic.
public type FulfilmentStatus record {|
    string orderId;
    string status;
    string message;
    string updatedAt;
|};

// Response body for a successfully submitted fulfilment command.
public type FulfilmentCommandAccepted record {|
    string message;
    string orderId;
|};

// Response body for a failed fulfilment command submission.
public type FulfilmentCommandError record {|
    string message;
|};

public type FulfilmentCommandAcceptedResponse record {|
    *http:Accepted;
    FulfilmentCommandAccepted body;
|};

public type FulfilmentCommandErrorResponse record {|
    *http:InternalServerError;
    FulfilmentCommandError body;
|};

// Health counters tracking how fulfilment commands were settled.
public type HealthCounters record {|
    int completedCount;
    int deadLetteredCount;
    int abandonedCount;
|};

public type HealthCountersResponse record {|
    *http:Ok;
    HealthCounters body;
|};
