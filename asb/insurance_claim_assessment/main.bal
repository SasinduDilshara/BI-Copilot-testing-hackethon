import ballerina/http;

// HTTP endpoint used to submit a batch of claim submissions for intake and assessment.
service /claims on new http:Listener(httpPort) {

    resource function post batchSubmissions(@http:Payload ClaimSubmissionBatch batch) returns ClaimBatchAcceptedResponse|ClaimBatchErrorResponse {
        error? submitResult = submitClaimBatch(batch.claims);
        if submitResult is error {
            ClaimBatchErrorResponse errorResponse = {
                body: {message: "Failed to submit claim batch: " + submitResult.message()}
            };
            return errorResponse;
        }

        ClaimBatchAcceptedResponse acceptedResponse = {
            body: {message: "Claim batch submitted", claimCount: batch.claims.length()}
        };
        return acceptedResponse;
    }

    resource function get health() returns OperationalCountersResponse {
        OperationalCounters counters = getOperationalCounters();
        OperationalCountersResponse countersResponse = {
            body: counters
        };
        return countersResponse;
    }
}
