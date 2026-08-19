import ballerina/http;
import ballerina/log;
import ballerina/sql;

service /claims on new http:Listener(servicePort) {
    resource function post submit(@http:Payload ClaimSubmission claim)
            returns http:Accepted|http:BadRequest|http:InternalServerError {
        Policyholder|sql:Error policyholder = getActivePolicyholder(claim.policyNumber);
        if policyholder is sql:NoRowsError {
            return <http:BadRequest>{body: string `Unknown policy ${claim.policyNumber}`};
        }
        if policyholder is sql:Error {
            log:printError(string `Failed to look up policy ${claim.policyNumber}`, 'error = policyholder);
            return <http:InternalServerError>{body: "Policy lookup failed"};
        }
        if !policyholder.isActive {
            return <http:BadRequest>{body: string `Policy ${claim.policyNumber} is inactive`};
        }

        error? result = processClaimWithRetry(claim, policyholder.coverageLimit);
        if result is error {
            log:printError(string `Failed to process claim ${claim.claimNumber}`, 'error = result);
            return <http:InternalServerError>{body: "Claim processing failed"};
        }
        return <http:Accepted>{body: string `Claim ${claim.claimNumber} accepted`};
    }
}
