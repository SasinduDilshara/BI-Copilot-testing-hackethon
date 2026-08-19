import ballerina/http;
import ballerina/log;

service /claims on new http:Listener(servicePort) {
    resource function post submit(@http:Payload ClaimSubmission claim)
            returns http:Accepted|http:InternalServerError {
        error? result = forwardToAdjudication(claim);
        if result is error {
            log:printError(string `Failed to forward claim ${claim.claimNumber}`, 'error = result);
            return <http:InternalServerError>{body: "Adjudication forwarding failed"};
        }
        return <http:Accepted>{body: string `Claim ${claim.claimNumber} accepted`};
    }
}
