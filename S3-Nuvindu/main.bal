import ballerina/log;
import ballerinax/aws.sqs;

@sqs:ServiceConfig {
    queueUrl: sqsQueueUrl,
    autoDelete: true
}
service on sqsListener {

    remote function onMessage(sqs:Message message) returns error? {
        string? messageBody = message.body;
        if messageBody is () {
            log:printError("Received an SQS message with an empty body, skipping");
            return;
        }

        error? processResult = processS3EventMessage(messageBody);
        if processResult is error {
            log:printError("Failed to process S3 event message, it will be retried by SQS",
                    processResult);
            return processResult;
        }
    }

    remote function onError(sqs:Error err) returns error? {
        log:printError("Error occurred while polling the SQS queue", err);
    }
}
