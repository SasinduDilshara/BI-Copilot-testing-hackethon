// Google Cloud Pub/Sub project and topic configuration.
configurable string projectId = ?;
configurable string topicName = ?;
configurable string credentialsPath = ?;

// Subscription that the telemetry storage service consumes from.
configurable string subscriptionName = ?;

// Regions allowed to submit telemetry. Readings from any other region are
// dropped and counted rather than stored.
configurable string[] allowedRegions = ?;

// Port for the health check HTTP service.
configurable int healthServicePort = 8080;
