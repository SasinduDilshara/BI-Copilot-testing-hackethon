// Google Cloud Pub/Sub project and credentials configuration.
configurable string projectId = ?;
configurable string credentialsPath = ?;

// Topic that order events are published to.
configurable string topicName = ?;

// Subscription that the order event subscriber service consumes from.
configurable string subscriptionName = ?;
