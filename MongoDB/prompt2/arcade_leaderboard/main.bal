
import ballerina/log;
import ballerinax/kafka;

listener kafka:Listener scoreSubmissionsListener = new (kafkaBootstrapServers, {
    groupId: kafkaConsumerGroupId,
    topics: [kafkaScoreSubmissionsTopic],
    offsetReset: "earliest",
    // Pull submissions in batches of up to 100 per poll for backpressure control.
    maxPollRecords: 100,
    // Offsets are committed manually only after every submission in the batch
    // has been attempted, so a crash mid-batch does not silently drop messages.
    autoCommit: false
});

service on scoreSubmissionsListener {
    remote function onConsumerRecord(kafka:AnydataConsumerRecord[] messages, kafka:Caller caller) returns error? {
        foreach kafka:AnydataConsumerRecord message in messages {
            processScoreSubmissionMessage(message);
        }

        kafka:Error? commitResult = caller->'commit();
        if commitResult is kafka:Error {
            log:printError("Failed to commit offsets for the processed score submission batch", 'error = commitResult);
        }
    }

    remote function onError(kafka:Error kafkaError) returns error? {
        log:printError("Error occurred while consuming score submissions from Kafka", 'error = kafkaError);
    }
}

function processScoreSubmissionMessage(kafka:AnydataConsumerRecord message) {
    anydata rawValue = message.value;
    byte[]|error messageBytes = trap <byte[]>rawValue;
    if messageBytes is error {
        log:printError("Skipping score submission message with an unexpected payload type", 'error = messageBytes);
        return;
    }

    string|error messageText = string:fromBytes(messageBytes);
    if messageText is error {
        log:printError("Skipping score submission message that is not valid UTF-8", 'error = messageText);
        return;
    }

    json|error submissionJson = messageText.fromJsonString();
    if submissionJson is error {
        log:printError("Skipping score submission message that is not valid JSON", 'error = submissionJson);
        return;
    }

    ScoreSubmission|error submission = submissionJson.cloneWithType(ScoreSubmission);
    if submission is error {
        log:printError("Skipping score submission message that does not match the expected schema",
                'error = submission);
        return;
    }

    // A single failing submission (e.g. a permanently invalid record) must not
    // stop the remaining submissions in the batch from being processed.
    error? result = recordHighScore(submission);
    if result is error {
        log:printError(string `Failed to record score for ${submission.playerId}`, 'error = result);
    }
}