// Represents a single order lifecycle event to be published to, or consumed
// from, the order events topic.
public type OrderEvent record {|
    string orderId;
    string eventType;
    string customerId;
    decimal totalAmount;
    string currency;
    string occurredAt;
|};
