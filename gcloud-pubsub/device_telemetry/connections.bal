import ballerina/http;
import ballerinax/gcloud.pubsub;

final pubsub:Publisher telemetryPublisher = check initTelemetryPublisher();

listener pubsub:Listener telemetryListener = check initTelemetryListener();

listener http:Listener telemetryHealthListener = new (healthServicePort);

// Wraps publisher construction in its own function so tests can replace it
// with a mock via @test:Mock, avoiding a real Pub/Sub connection attempt
// during module initialization.
function initTelemetryPublisher() returns pubsub:Publisher|error {
    return new (
        topicName,
        projectId = projectId,
        credentials = {
            credentialsPath: credentialsPath
        }
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
