import ballerinax/nats;

configurable string natsUrl = "nats://localhost:4222";
configurable string connectionName = "telemetry-collector-service";

// Username/password used to authenticate with the NATS server.
configurable string natsUsername = ?;
configurable string natsPassword = ?;

// TLS truststore used to secure the connection to the NATS server.
configurable string tlsTrustStorePath = ?;
configurable string tlsTrustStorePassword = ?;

// Readings whose readingAt timestamp is older than this many seconds, relative to the
// time they are consumed, are considered stale - dropped (not processed) and counted
// rather than raising a processing error.
configurable decimal stalenessWindowSeconds = 300;

// Caps how many messages/bytes the telemetry subscription will buffer while awaiting
// processing, across every device subject under telemetry.>.
configurable int subscriptionMaxPendingMessages = 10000;
configurable int subscriptionMaxPendingBytes = 10485760;

final nats:PendingLimits telemetryPendingLimits = {
    maxMessages: subscriptionMaxPendingMessages,
    maxBytes: subscriptionMaxPendingBytes
};

// Per-device-type alert thresholds. When a reading's metric value crosses (exceeds) the
// threshold configured for its device type, an alert is published to telemetry.alerts.
// Device types without a configured threshold are never alerted on.
configurable map<decimal> deviceTypeAlertThresholds = {
    fridge: 8.0,
    freezer: -12.0
};
