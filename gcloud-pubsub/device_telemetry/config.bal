// Google Cloud Pub/Sub project and topic configuration.
configurable string projectId = ?;
configurable string topicName = ?;
configurable string credentialsPath = ?;

// Batching configuration for the publisher.
configurable int batchElementCountThreshold = 100;
configurable int batchByteSizeThreshold = 1048576;
configurable int batchDelayThresholdMillis = 10;
