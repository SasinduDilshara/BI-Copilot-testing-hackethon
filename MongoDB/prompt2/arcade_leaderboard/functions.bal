
import ballerina/lang.runtime;
import ballerina/log;
import ballerinax/mongodb;

const int MAX_RETRY_ATTEMPTS = 3;
const decimal RETRY_BASE_DELAY_SECONDS = 0.250;

function recordHighScore(ScoreSubmission submission) returns error? {
    int attempt = 0;
    while true {
        mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError|error updateResult =
            scoresCollection->updateOne(
            {playerId: submission.playerId, levelId: submission.levelId},
            {
                max: {score: submission.score},
                setOnInsert: {playerId: submission.playerId, levelId: submission.levelId}
            },
            {upsert: true}
        );

        if updateResult is mongodb:UpdateResult {
            return;
        }

        error updateError = updateResult;
        if isDuplicateKeyError(updateError) {
            // Two concurrent submissions raced the upsert and both matched the
            // unique compound index; the score is already persisted by the
            // other request, so this is an expected outcome, not a failure.
            log:printInfo(string `Duplicate high score submission treated as expected race for ${submission.playerId}/${submission.levelId}`);
            return;
        }

        if !isRetryableError(updateError) {
            return updateError;
        }

        attempt += 1;
        if attempt > MAX_RETRY_ATTEMPTS {
            log:printWarn(string `Exhausted retries recording score for ${submission.playerId}, dead-lettering submission`,
                    'error = updateError);
            return deadLetterSubmission(submission, updateError);
        }

        decimal backoffSeconds = RETRY_BASE_DELAY_SECONDS * (2 ^ (attempt - 1));
        log:printWarn(string `Retryable failure recording score for ${submission.playerId}, attempt ${attempt} of ${MAX_RETRY_ATTEMPTS}, retrying in ${backoffSeconds}s`,
                'error = updateError);
        runtime:sleep(backoffSeconds);
    }
}

function isDuplicateKeyError(error updateError) returns boolean {
    string errorMessage = updateError.message();
    return errorMessage.includes("E11000") || errorMessage.toLowerAscii().includes("duplicate key");
}

function isRetryableError(error updateError) returns boolean {
    string lowerCaseMessage = updateError.message().toLowerAscii();
    return lowerCaseMessage.includes("timeout")
        || lowerCaseMessage.includes("timed out")
        || lowerCaseMessage.includes("connection")
        || lowerCaseMessage.includes("not primary")
        || lowerCaseMessage.includes("no primary")
        || lowerCaseMessage.includes("network");
}

function deadLetterSubmission(ScoreSubmission submission, error cause) returns error? {
    record {|
        string playerId;
        string levelId;
        int score;
        string submittedAt;
        string failureReason;
    |} deadLetterRecord = {
        playerId: submission.playerId,
        levelId: submission.levelId,
        score: submission.score,
        submittedAt: submission.submittedAt,
        failureReason: cause.message()
    };

    mongodb:DatabaseError|mongodb:ApplicationError|error|() insertResult =
        scoresDlqCollection->insertOne(deadLetterRecord);
    if insertResult is error {
        log:printError(string `Failed to dead-letter score submission for ${submission.playerId}`, 'error = insertResult);
        return insertResult;
    }
}