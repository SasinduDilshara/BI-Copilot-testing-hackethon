import ballerina/http;
import ballerina/log;

listener http:Listener policyListener = new (httpPort);

service /policies on policyListener {

    # Receives a new insurance policy application and binds it, persisting the calculated
    # premium breakdown to the policies and ledger_entries tables in a single transaction.
    # Retries transient connection failures with exponential backoff, and falls back to the
    # dead letter queue if the bind operation ultimately fails.
    #
    # + bindRequest - the incoming policy bind request
    # + return - the bind outcome
    resource function post bind(@http:Payload PolicyBindRequest bindRequest)
            returns PolicyBoundResponse|http:Accepted|http:InternalServerError {
        PolicyBoundResponse|error bindResult = bindPolicyWithRetry(bindRequest);
        if bindResult is PolicyBoundResponse {
            return bindResult;
        }

        string failureReason = bindResult.message();
        log:printError("Policy bind failed after retries, writing to dead letter queue",
                policyId = bindRequest.policyId, 'error = bindResult);

        error? dlqResult = writeToDeadLetterQueue(bindRequest, failureReason);
        if dlqResult is error {
            ErrorResponse errorResponse = {
                message: string `Policy bind failed and could not be persisted to the dead letter queue: ${dlqResult.message()}`
            };
            return <http:InternalServerError>{body: errorResponse};
        }

        PolicyQueuedResponse queuedResponse = {
            policyId: bindRequest.policyId,
            message: "Policy bind failed after retries and has been queued for reprocessing"
        };
        return <http:Accepted>{body: queuedResponse};
    }
}
