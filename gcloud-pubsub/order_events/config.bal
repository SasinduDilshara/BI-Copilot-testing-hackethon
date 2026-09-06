// Google Cloud Pub/Sub project and credentials configuration.
configurable string projectId = ?;
configurable string credentialsPath = ?;

// Topic that order events are published to.
configurable string topicName = ?;

// Subscription that the order event subscriber service consumes from.
configurable string subscriptionName = ?;

// Topic that order events are republished to once they exceed
// maxDeliveryAttempts, carrying the failure reason as a message attribute.
configurable string poisonTopicName = ?;

// Maximum number of delivery attempts tracked in-process for a message
// before it is published to the poison topic instead of being nacked again.
// The installed ballerinax/gcloud.pubsub connector has no admin API to create
// topics/subscriptions or to configure a real dead-letter policy on the
// subscription, so this is enforced entirely in application code rather than
// by the broker.
configurable int maxDeliveryAttempts = 5;
