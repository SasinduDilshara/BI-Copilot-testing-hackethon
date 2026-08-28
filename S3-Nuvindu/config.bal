// SQS connection and queue configuration, provided through environment-based configuration.
// AWS credentials must belong to an IAM identity granted sqs:ReceiveMessage, sqs:DeleteMessage,
// and sqs:ChangeMessageVisibility on the company-s3-events queue.
configurable string awsAccessKeyId = ?;
configurable string awsSecretAccessKey = ?;
configurable string awsRegion = "us-east-1";
configurable string sqsQueueUrl = ?;

// SQS polling configuration.
configurable decimal sqsPollIntervalSeconds = 1.0;
configurable int sqsWaitTimeSeconds = 20;

// Dead-letter queue configuration for messages that repeatedly fail processing.
configurable string sqsDeadLetterQueueName = "company-s3-events-dlq";
configurable int sqsMaxReceiveCount = 5;
configurable int sqsVisibilityTimeoutSeconds = 60;

// Port on which the runtime health check endpoint is exposed.
configurable int healthCheckPort = 9090;
