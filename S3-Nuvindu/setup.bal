import ballerina/log;
import ballerinax/aws.sqs;

// Provision the dead-letter queue and redrive policy once, when this module is initialized,
// before the listener starts polling for messages.
function init() returns error? {
    check initializeQueueFailureHandling();
}

// Ensures the dead-letter queue exists and that the main queue is configured with a redrive
// policy pointing to it, along with the required visibility timeout. This runs once at
// module initialization so the redrive/DLQ setup is self-contained in the application.
function initializeQueueFailureHandling() returns error? {
    string dlqUrl = check getOrCreateDeadLetterQueueUrl();
    string dlqArn = check getQueueArn(dlqUrl);

    sqs:RedrivePolicy redrivePolicy = {
        deadLetterTargetArn: dlqArn,
        maxReceiveCount: sqsMaxReceiveCount
    };
    sqs:QueueAttributes mainQueueAttributes = {
        visibilityTimeout: sqsVisibilityTimeoutSeconds,
        redrivePolicy: redrivePolicy
    };
    check sqsManagementClient->setQueueAttributes(sqsQueueUrl, mainQueueAttributes);
    log:printInfo("Configured dead-letter queue and visibility timeout for the main queue",
            deadLetterQueueUrl = dlqUrl, maxReceiveCount = sqsMaxReceiveCount,
            visibilityTimeoutSeconds = sqsVisibilityTimeoutSeconds);
}

// Returns the URL of the configured dead-letter queue, creating it first if it does not exist.
function getOrCreateDeadLetterQueueUrl() returns string|error {
    string|sqs:Error existingQueueUrl = sqsManagementClient->getQueueUrl(sqsDeadLetterQueueName);
    if existingQueueUrl is string {
        return existingQueueUrl;
    }
    log:printInfo("Dead-letter queue not found, creating it", queueName = sqsDeadLetterQueueName);
    return sqsManagementClient->createQueue(sqsDeadLetterQueueName);
}

// Retrieves the ARN attribute of the given queue.
function getQueueArn(string queueUrl) returns string|error {
    sqs:GetQueueAttributesResponse attributesResponse = check sqsManagementClient->getQueueAttributes(queueUrl,
            attributeNames = [sqs:QUEUE_ARN]);
    string? queueArn = attributesResponse.queueAttributes["QueueArn"];
    if queueArn is () {
        return error("Queue ARN attribute was not returned for queue: " + queueUrl);
    }
    return queueArn;
}
