import ballerinax/gcloud.pubsub;

final pubsub:Publisher orderEventPublisher = check initOrderEventPublisher();

final pubsub:Publisher poisonEventPublisher = check initPoisonEventPublisher();

listener pubsub:Listener orderEventListener = check initOrderEventListener();

// Wraps publisher construction in its own function so tests can replace it
// with a mock via @test:Mock, avoiding a real Pub/Sub connection attempt
// during module initialization.
function initOrderEventPublisher() returns pubsub:Publisher|error {
    return new (
        topicName,
        projectId = projectId,
        credentials = {
            credentialsPath: credentialsPath
        }
    );
}

// Wraps publisher construction for the poison topic in its own function so
// tests can replace it with a mock via @test:Mock, avoiding a real Pub/Sub
// connection attempt during module initialization.
function initPoisonEventPublisher() returns pubsub:Publisher|error {
    return new (
        poisonTopicName,
        projectId = projectId,
        credentials = {
            credentialsPath: credentialsPath
        }
    );
}

// Wraps listener construction in its own function so tests can replace it
// with a mock via @test:Mock, avoiding a real Pub/Sub connection attempt
// during module initialization.
function initOrderEventListener() returns pubsub:Listener|error {
    return new (
        subscriptionName,
        projectId = projectId,
        credentials = {
            credentialsPath: credentialsPath
        }
    );
}
