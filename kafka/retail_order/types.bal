import ballerinax/kafka;

// Represents an order event consumed from the `orders.created` Kafka topic.
// The upstream event now carries the customer's tier, email, and country directly.
public type OrderEvent record {|
    string orderId;
    string customerId;
    decimal orderAmount;
    string currency;
    int itemCount;
    string channel;
    string customerTier;
    string customerEmail;
    string customerCountry;
|};

// Represents a Kafka consumer record whose value is bound to the `OrderEvent` type.
public type OrderEventConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    OrderEvent value;
|};

// Represents an order event ready for publishing to the enriched topic.
public type EnrichedOrder record {|
    string orderId;
    string customerId;
    decimal orderAmount;
    string currency;
    int itemCount;
    string channel;
    string customerTier;
    string customerEmail;
    string customerCountry;
|};

// Error raised when an order event payload is structurally invalid (including
// missing customer fields) and must be routed straight to the DLQ.
public type InvalidOrderEventError distinct error;
