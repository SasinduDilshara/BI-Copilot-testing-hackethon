import ballerina/log;
import ballerinax/aws.sqs;

@sqs:ServiceConfig {
    queueUrl: sqsQueueUrl,
    autoDelete: true
}
service on sqsListener {

    remote function onMessage(sqs:Message message) returns error? {
        string? messageId = message.messageId;
        int? approximateReceiveCount = message?.messageSystemAttributes?.approximateReceiveCount;

        logMessageReceived(messageId, approximateReceiveCount);

        string? messageBody = message.body;
        if messageBody is () {
            logValidationFailure(messageId, "Message body is empty");
            return;
        }

        error? processResult = processS3EventMessage(messageBody, messageId);
        if processResult is error {
            processingFailuresCounter.increment();
            logProcessingFailure(messageId, approximateReceiveCount, processResult.message());

            // The redrive policy moves a message to the DLQ once it has been received
            // sqsMaxReceiveCount times without being deleted. This is the last attempt before
            // that happens, so it is counted here as an approximation of "sent to DLQ" - the
            // actual move is performed by SQS itself and is not directly observable by this
            // application.
            if approximateReceiveCount is int && approximateReceiveCount >= sqsMaxReceiveCount {
                messagesSentToDlqCounter.increment();
            }
            return processResult;
        }

        messagesProcessedCounter.increment();
    }

    remote function onError(sqs:Error err) returns error? {
        log:printError("Error occurred while polling the SQS queue", err);
    }
}
