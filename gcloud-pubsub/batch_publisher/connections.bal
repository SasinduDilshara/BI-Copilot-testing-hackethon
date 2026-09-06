import ballerina/http;
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
