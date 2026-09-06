// Google Cloud Pub/Sub project and topic configuration.
configurable string projectId = ?;
configurable string topicName = ?;

// Selects how the service account key material below is supplied.
configurable AuthMode authMode = "filePath";

// Path to the service account key file used to authenticate with Google
// Cloud Pub/Sub. Required when authMode is "filePath".
configurable string credentialsPath = "";

// The service account key, as a JSON string, used to authenticate with
// Google Cloud Pub/Sub. Required when authMode is "jsonString".
configurable string credentialsJson = "";

// Subscription that messages are pulled from for operational spot checks.
configurable string subscriptionName = ?;

// Maximum number of messages to pull in a single synchronous pull call.
configurable int pullMaxMessages = 10;

// Port for the aggregation publisher HTTP service.
configurable int servicePort = 8081;
