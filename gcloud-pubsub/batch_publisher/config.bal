// Google Cloud Pub/Sub project and topic configuration.
configurable string projectId = ?;
configurable string topicName = ?;

// Path to the service account key file used to authenticate with Google
// Cloud Pub/Sub.
configurable string credentialsPath = ?;

// Port for the aggregation publisher HTTP service.
configurable int servicePort = 8081;
