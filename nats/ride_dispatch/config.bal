import ballerinax/nats;

configurable string natsUrl = "nats://localhost:4222";
configurable string connectionName = "ride-dispatch-service";

// Reconnect retry configuration for the NATS connection.
configurable int maxReconnect = 60;
configurable decimal reconnectWait = 2;
configurable decimal connectionTimeout = 2;

final nats:RetryConfig natsRetryConfig = {
    maxReconnect: maxReconnect,
    reconnectWait: reconnectWait,
    connectionTimeout: connectionTimeout
};

// Cities this deployment serves. Ride requests for any other city are published
// to rides.rejected instead of being dispatched.
configurable string[] servedCities = ["colombo"];

// Caps how many messages/bytes the dispatch subscription will buffer while awaiting processing.
configurable int subscriptionMaxPendingMessages = 1000;
configurable int subscriptionMaxPendingBytes = 1048576;

final nats:PendingLimits dispatchPendingLimits = {
    maxMessages: subscriptionMaxPendingMessages,
    maxBytes: subscriptionMaxPendingBytes
};
