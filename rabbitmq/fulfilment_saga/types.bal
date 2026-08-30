# Represents a single line item within a fulfilment request.
public type OrderItem record {|
    string sku;
    int quantity;
|};

# Represents an incoming order fulfilment request.
public type FulfilmentRequest record {|
    string orderId;
    string warehouseId;
    OrderItem[] items;
    string shippingMethod;
|};

# Represents the payload published to `inventory.reserve` asking the inventory system to
# reserve stock for an order.
public type ReservationRequest record {|
    string orderId;
    string warehouseId;
    OrderItem[] items;
|};

# Represents the reply the inventory responder publishes back to the caller's `replyTo` queue.
public type ReservationResponse record {|
    string orderId;
    boolean reserved;
    string message?;
|};

# Generic error message body used by error responses.
public type ErrorMessage record {|
    string message;
|};

# Response body returned immediately after a fulfilment request is accepted for processing.
# The saga runs asynchronously; poll the saga status endpoint for the outcome.
public type FulfilmentAccepted record {|
    string orderId;
    string statusUrl;
|};

# The distinct stages a fulfilment saga can be in.
public enum SagaStatus {
    SAGA_STARTED = "STARTED",
    SAGA_AWAITING_RESERVATION = "AWAITING_RESERVATION",
    SAGA_INVENTORY_RESERVED = "INVENTORY_RESERVED",
    SAGA_PAYMENT_CHARGED = "PAYMENT_CHARGED",
    SAGA_COMPLETED = "COMPLETED",
    SAGA_INVENTORY_RELEASED = "INVENTORY_RELEASED",
    SAGA_FAILED = "FAILED"
}

# Tracks the progress (and any compensating actions) of a single order's fulfilment saga.
public type SagaState record {|
    string orderId;
    SagaStatus status;
    string[] completedSteps;
    string[] compensatingSteps;
    string? failureReason;
    string lastUpdated;
|};
