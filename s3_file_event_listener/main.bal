import ballerina/log;
import ballerinax/aws.sqs;

@sqs:ServiceConfig {
    queueUrl: queueUrl,
    autoDelete: true
}
service on sqsListener {

    remote function onMessage(sqs:Message message) returns error? {
        check processS3EventMessage(message.body);
    }

    remote function onError(sqs:Error err) returns error? {
        log:printError("Error occurred while receiving messages from the SQS queue", err);
    }
}
