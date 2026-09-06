import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerinax/gcloud.pubsub;

final pubsub:Publisher aggregatePublisher = check initAggregatePublisher();

listener http:Listener aggregateServiceListener = new (servicePort);

// Wraps publisher construction in its own function so tests can replace it
// with a mock via @test:Mock, avoiding a real Pub/Sub connection attempt
// during module initialization.
function initAggregatePublisher() returns pubsub:Publisher|error {
    return new (
        topicName,
        projectId = projectId,
        credentials = {
            credentialsPath: credentialsPath
        }
    );
}

// Ensures the publisher is closed and releases its resources when the
// service shuts down gracefully.
function closeAggregatePublisher() returns error? {
    pubsub:Error? result = aggregatePublisher->close();
    if result is pubsub:Error {
        log:printError("Failed to close aggregate publisher cleanly", result);
        return result;
    }
}

function init() {
    runtime:onGracefulStop(closeAggregatePublisher);
}
