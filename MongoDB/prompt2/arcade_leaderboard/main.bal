
import ballerina/http;
import ballerina/log;

service /scores on new http:Listener(8097) {
    resource function post submit(@http:Payload ScoreSubmission submission)
            returns http:Accepted|http:InternalServerError {
        error? result = recordHighScore(submission);
        if result is error {
            log:printError(string `Failed to record score for ${submission.playerId}`, 'error = result);
            return <http:InternalServerError>{body: "Score recording failed"};
        }
        return <http:Accepted>{body: "Score recorded"};
    }
}