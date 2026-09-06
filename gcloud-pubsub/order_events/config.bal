// Google Cloud Pub/Sub project and credentials configuration.
configurable string projectId = ?;
configurable string credentialsPath = ?;

// Topic that order events are published to.
configurable string topicName = ?;

// Subscription that the order event subscriber service consumes from.
configurable string subscriptionName = ?;

// Maximum number of delivery attempts tracked locally for a message before it
// is treated as exhausted. NOTE: the installed ballerinax/gcloud.pubsub
// connector has no admin API to create topics/subscriptions or to configure a
// real dead-letter policy on the subscription - that must be provisioned out
// of band (e.g. via the gcloud CLI, Console, or Terraform) using this same
// value for --max-delivery-attempts. This configurable only drives the local,
// in-memory delivery-attempt counter used to report how close a message is to
// its configured dead-letter threshold.
configurable int maxDeliveryAttempts = 5;
