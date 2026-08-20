// GPS check-in coordinates captured by the field-service mobile app.
public type GpsCheckIn record {|
    decimal latitude;
    decimal longitude;
|};

// A single part consumed while completing the work order.
public type PartConsumed record {|
    string sku;
    int quantity;
|};

// Incoming work-order completion event from the field-service mobile app.
public type WorkOrderCompletionEvent record {|
    string workOrderId;
    string technicianId;
    GpsCheckIn gpsCheckIn;
    PartConsumed[] partsConsumed;
|};

// Response returned when the completion event was persisted successfully.
public type CompletionAccepted record {|
    string workOrderId;
    string status;
|};

// Response returned when the event could not be persisted even after retries,
// but was safely written to the dead-letter queue.
public type CompletionDeadLettered record {|
    string workOrderId;
    string status;
    string reason;
|};

// Internal outcome markers for processWorkOrderCompletion.
type CompletionPersisted record {|
|};

type CompletionSentToDlq record {|
    error cause;
|};
