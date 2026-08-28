// SQS connection and queue configuration, provided through environment-based configuration.
configurable string awsAccessKeyId = ?;
configurable string awsSecretAccessKey = ?;
configurable string sqsQueueUrl = ?;

// Dead-letter queue configuration for messages that repeatedly fail processing.
configurable string sqsDeadLetterQueueName = "company-s3-events-dlq";
configurable int sqsMaxReceiveCount = 5;
configurable int sqsVisibilityTimeoutSeconds = 60;
