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

# Outcome of a single content delivery attempt to a subscriber callback.
public enum DeliveryOutcome {
    DELIVERY_SUCCESS = "SUCCESS",
    DELIVERY_TRANSIENT_FAILURE = "TRANSIENT_FAILURE",
    DELIVERY_SUBSCRIPTION_DELETED = "SUBSCRIPTION_DELETED"
}

# Represents a single recorded delivery attempt made to a subscriber callback.
#
# + topic - Topic the delivered content belongs to
# + callback - Callback URL the content was delivered to
# + timestamp - RFC 3339 timestamp at which the delivery attempt was made
# + outcome - Outcome of the delivery attempt
public type DeliveryAttempt record {|
    string topic;
    string callback;
    string timestamp;
    DeliveryOutcome outcome;
|};

# Operational counters for subscription and delivery activity.
#
# + acceptedSubscriptions - Total number of subscriptions accepted and verified
# + rejectedSubscriptions - Total number of subscriptions rejected during validation
# + successfulDeliveries - Total number of delivery attempts that succeeded
# + failedDeliveries - Total number of delivery attempts that failed (transient or subscription deleted)
public type OperationalCounters record {|
    int acceptedSubscriptions;
    int rejectedSubscriptions;
    int successfulDeliveries;
    int failedDeliveries;
|};

# Admin view of currently registered topics.
#
# + topics - List of currently registered topic URLs
public type TopicsAdminView record {|
    string[] topics;
|};

# Admin view of currently verified subscriptions along with subscription counters.
#
# + subscriptions - List of currently verified subscriptions
# + acceptedSubscriptions - Total number of subscriptions accepted and verified
# + rejectedSubscriptions - Total number of subscriptions rejected during validation
public type SubscriptionsAdminView record {|
    VerifiedSubscriber[] subscriptions;
    int acceptedSubscriptions;
    int rejectedSubscriptions;
|};

# Admin view of recorded delivery attempts along with delivery counters.
#
# + deliveries - List of recorded delivery attempts
# + successfulDeliveries - Total number of delivery attempts that succeeded
# + failedDeliveries - Total number of delivery attempts that failed (transient or subscription deleted)
public type DeliveriesAdminView record {|
    DeliveryAttempt[] deliveries;
    int successfulDeliveries;
    int failedDeliveries;
|};
