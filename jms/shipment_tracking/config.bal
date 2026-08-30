// ActiveMQ Artemis broker connection URL.
configurable string providerUrl = "tcp://localhost:61616";

// Queue that the legacy system publishes JSON shipment status events to.
configurable string shipmentStatusInQueue = "SHIPMENT.STATUS.IN";

// Default queue that accepted (non-exception) shipment status events are published to when the
// carrier is not present in carrierStatusOutQueues.
configurable string defaultShipmentStatusOutQueue = "SHIPMENT.STATUS.OUT";

// Default queue that exception shipment status events are published to when the carrier is not
// present in carrierExceptionQueues.
configurable string defaultShipmentExceptionQueue = "SHIPMENT.EXCEPTIONS";

// Per-carrier destination queues for accepted shipment status events, keyed by carrierCode.
// Carriers not present here fall back to defaultShipmentStatusOutQueue.
configurable map<string> carrierStatusOutQueues = {};

// Per-carrier destination queues for exception shipment status events, keyed by carrierCode.
// Carriers not present here fall back to defaultShipmentExceptionQueue.
configurable map<string> carrierExceptionQueues = {};

// JMS priority (0-9) used for exception events, higher than normal accepted events so they are
// dispatched ahead of routine status updates.
configurable int exceptionPriority = 7;

// Time-to-live, in milliseconds, applied to exception events so they expire instead of being
// processed indefinitely if left unconsumed.
configurable int exceptionTtlMillis = 86400000;

// Queue that messages failing JSON binding are routed to, with the error category attached as a
// message property.
configurable string shipmentStatusDlqQueue = "SHIPMENT.STATUS.DLQ";
