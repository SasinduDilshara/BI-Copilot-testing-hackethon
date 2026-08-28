import ballerina/log;
import ballerinax/aws.sqs;

@sqs:ServiceConfig {
    queueUrl: sqsQueueUrl,
    autoDelete: true
}
service on sqsListener {

    remote function onMessage(sqs:Message message) returns error? {
        string? messageId = message.messageId;
        string? messageBody = message.body;
        if messageBody is () {
            log:printError("Received an SQS message with an empty body, skipping", messageId = messageId);
            return;
        }

        error? processResult = processS3EventMessage(messageBody, messageId);
        if processResult is error {
            log:printError("Failed to process S3 event message, it will be retried by SQS",
                    processResult, messageId = messageId);
            return processResult;
        }
    }

    remote function onError(sqs:Error err) returns error? {
        log:printError("Error occurred while polling the SQS queue", err);
    }
}
