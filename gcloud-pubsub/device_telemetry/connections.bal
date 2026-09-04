import ballerinax/gcloud.pubsub;

// Message ordering requires enableMessageOrdering to be turned on. Without it,
// the orderingKey on a message is ignored by the client library, messages are
// sent over multiple concurrent batching streams, and readings for the same
// device can be delivered/processed out of order.
final pubsub:Publisher telemetryPublisher = check initTelemetryPublisher();

listener pubsub:Listener telemetryListener = check initTelemetryListener();

// Wraps publisher construction in its own function so tests can replace it
// with a mock via @test:Mock, avoiding a real Pub/Sub connection attempt
// during module initialization.
function initTelemetryPublisher() returns pubsub:Publisher|error {
    return new (
        topicName,
        projectId = projectId,
        credentials = {
            credentialsPath: credentialsPath
        },
        enableBatching = true,
        batchSettings = {
            elementCountThreshold: batchElementCountThreshold,
            requestByteSizeThreshold: batchByteSizeThreshold,
            delayThresholdMillis: batchDelayThresholdMillis
        },
        enableMessageOrdering = true
    );
}

// Wraps listener construction in its own function so tests can replace it
// with a mock via @test:Mock, avoiding a real Pub/Sub connection attempt
// during module initialization.
function initTelemetryListener() returns pubsub:Listener|error {
    return new (
        subscriptionName,
        projectId = projectId,
        credentials = {
            credentialsPath: credentialsPath
        }
    );
}
