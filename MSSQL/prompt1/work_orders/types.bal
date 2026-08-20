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

// Compensating message published to the inventory service so it can decrement
// stock asynchronously. idempotencyKey is derived deterministically from the
// work order ID so that redelivering/retrying the same event can never cause
// the inventory service to double-decrement.
public type DecrementStockMessage record {|
    string idempotencyKey;
    string workOrderId;
    PartConsumed[] partsConsumed;
|};

// Payload sent to the existing /incidents/report webhook so it can page
// on-call when the work-order completion transaction fails even after retries.
public type IncidentReport record {|
    string workOrderId;
    string technicianId;
    string rawEvent;
    string errorMessage;
|};

// Response returned when the completion event was persisted successfully.
public type CompletionAccepted record {|
    string workOrderId;
    "COMPLETED" status;
|};

// Response returned when the event could not be persisted even after retries,
// but an incident was successfully reported to page on-call.
public type CompletionIncidentReported record {|
    string workOrderId;
    "INCIDENT_REPORTED" status;
    string reason;
|};

// Response returned when the event could not be persisted even after retries,
// the incident webhook call itself also failed, and the event was instead
// written to the dead-letter queue as a last resort.
public type CompletionDeadLettered record {|
    string workOrderId;
    "DEAD_LETTERED" status;
    string reason;
|};

// Internal outcome markers for processWorkOrderCompletion.
type CompletionPersisted record {|
    "PERSISTED" outcome;
|};

type CompletionReportedAsIncident record {|
    "INCIDENT_REPORTED" outcome;
    error cause;
|};

type CompletionSentToDlq record {|
    "DEAD_LETTERED" outcome;
    error cause;
|};
