import ballerinax/asb;

// Exponential AMQP retry configuration shared by the sender and receiver clients.
final asb:AmqpRetryOptions amqpRetryOptions = {
    maxRetries: amqpMaxRetries,
    delay: amqpRetryDelaySeconds,
    maxDelay: amqpMaxRetryDelaySeconds,
    tryTimeout: amqpTryTimeoutSeconds,
    retryMode: asb:EXPONENTIAL
};

// Administrator client used to provision the claims-intake queue.
final asb:Administrator asbAdmin = check new (connectionString);

// Sender used by the HTTP intake endpoint to submit claim submission batches to the
// claims-intake queue.
final asb:MessageSender claimsIntakeSender = check new ({
    connectionString: connectionString,
    entityType: asb:QUEUE,
    topicOrQueueName: claimsIntakeQueue,
    amqpRetryOptions: amqpRetryOptions
});

// Receiver used by the claim-assessment worker to receive batches of claim submissions
// in PEEK_LOCK mode so that each claim can be explicitly completed, abandoned, or
// dead-lettered based on the outcome of assessment.
final asb:MessageReceiver claimsIntakeReceiver = check new ({
    connectionString: connectionString,
    entityConfig: {
        queueName: claimsIntakeQueue
    },
    receiveMode: asb:PEEK_LOCK,
    amqpRetryOptions: amqpRetryOptions
});

// Tracks how claim messages have been settled (completed, dead-lettered, or abandoned).
isolated OperationalCounters operationalCounters = {
    completedCount: 0,
    deadLetteredCount: 0,
    abandonedCount: 0
};
