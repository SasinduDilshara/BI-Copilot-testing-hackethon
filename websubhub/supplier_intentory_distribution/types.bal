// Type definitions for the supplier inventory distribution WebSub hub.

# Represents a stock update event for a supplier inventory item.
#
# + eventId - Unique identifier of the stock update event
# + sku - Stock keeping unit of the inventory item
# + warehouseId - Identifier of the warehouse where the stock update occurred
# + availableQuantity - Available quantity of the item after the update
# + occurredAt - Timestamp (ISO 8601) at which the update occurred
public type StockUpdate record {|
    string eventId;
    string sku;
    string warehouseId;
    int availableQuantity;
    string occurredAt;
|};

# Represents a verified subscriber that is being tracked in-memory by the hub.
#
# + hubTopic - Topic the subscriber is subscribed to
# + hubCallback - Callback URL of the subscriber
# + hubLeaseSeconds - Lease period (in seconds) agreed for the subscription
# + hubSecret - Optional secret used for authenticated content distribution
public type VerifiedSubscriber record {|
    string hubTopic;
    string hubCallback;
    string? hubLeaseSeconds;
    string? hubSecret;
|};
