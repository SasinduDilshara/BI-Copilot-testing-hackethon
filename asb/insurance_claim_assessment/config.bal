// Azure Service Bus connection string (shared access policy connection string).
configurable string connectionString = ?;

// Queue that carries incoming claim submissions for intake and assessment.
configurable string claimsIntakeQueue = "claims-intake";

// HTTP listener port for the claim submission endpoint.
configurable int httpPort = 8080;

// Maximum number of messages received per batch poll from the claims-intake queue.
configurable int receiveBatchSize = 10;

// Server wait time (in seconds) when polling for a batch of messages.
configurable int receiveServerWaitTimeSeconds = 5;

// --- Claims-intake queue provisioning settings ---

// Default message time-to-live applied to claim submissions, in seconds.
configurable int claimMessageTimeToLiveSeconds = 3600;

// Lock duration applied while a receiver is processing a claim message, in seconds.
configurable int claimLockDurationSeconds = 60;

// Maximum number of delivery attempts before a claim message is dead-lettered automatically.
configurable int claimMaxDeliveryCount = 5;

// Duplicate detection history time window, in seconds.
configurable int duplicateDetectionWindowSeconds = 600;

// --- AMQP retry settings (exponential backoff) ---

// Maximum number of AMQP retry attempts.
configurable int amqpMaxRetries = 5;

// Initial delay between AMQP retry attempts, in seconds.
configurable decimal amqpRetryDelaySeconds = 1d;

// Maximum delay between AMQP retry attempts, in seconds.
configurable decimal amqpMaxRetryDelaySeconds = 60d;

// Timeout applied to each AMQP operation attempt, in seconds.
configurable decimal amqpTryTimeoutSeconds = 60d;
