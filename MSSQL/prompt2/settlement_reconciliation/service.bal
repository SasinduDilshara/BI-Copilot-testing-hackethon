import ballerina/http;
import ballerina/log;

listener http:Listener settlementListener = new (webhookListenerPort);

function init() returns error? {
    check ensureSettlementSchema();
}

service /settlements on settlementListener {

    # Receives a batch of settlements pushed by the processor and reconciles them into the
    # settlements table, applying retry-with-backoff and dead-lettering for genuine failures.
    resource function post incoming(@http:Header string? x\-processor\-api\-key, @http:Payload SettlementRecord[] batch)
            returns http:Accepted|http:Unauthorized|http:InternalServerError {
        if x\-processor\-api\-key != processorWebhookApiKey {
            return <http:Unauthorized>{body: {message: "Invalid or missing processor API key"}};
        }

        error? result = insertSettlementBatch(batch);
        if result is error {
            log:printError("Settlement reconciliation failed for incoming webhook batch", 'error = result);
            return <http:InternalServerError>{body: {message: "Failed to reconcile settlement batch"}};
        }

        return <http:Accepted>{body: {message: "Settlement batch accepted", recordCount: batch.length()}};
    }
}
