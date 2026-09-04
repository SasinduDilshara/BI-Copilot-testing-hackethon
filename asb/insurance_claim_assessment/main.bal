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

    // Lists claims currently deferred for manual review, including the sequence
    // numbers needed to receive them later.
    resource function get deferred() returns DeferredClaimsResponse {
        DeferredClaim[] deferredClaims = getDeferredClaims();
        DeferredClaimsResponse deferredClaimsResponse = {
            body: deferredClaims
        };
        return deferredClaimsResponse;
    }

    // Receives a previously deferred manual-review claim by its Service Bus sequence
    // number, finalizes its assessment, publishes the result, and completes the message.
    resource function post deferred/[int sequenceNumber]/receive() returns ClaimAssessmentResultResponse|DeferredClaimNotFoundResponse {
        ClaimAssessmentResult|error result = receiveDeferredClaim(sequenceNumber);
        if result is error {
            DeferredClaimNotFoundResponse notFoundResponse = {
                body: {message: "Failed to receive deferred claim: " + result.message()}
            };
            return notFoundResponse;
        }

        ClaimAssessmentResultResponse resultResponse = {
            body: result
        };
        return resultResponse;
    }
}
