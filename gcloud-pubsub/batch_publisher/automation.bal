import ballerina/http;

// Exposes an endpoint to publish a batch of aggregate records to Google
// Cloud Pub/Sub in a single call.
service /aggregates on aggregateServiceListener {

    resource function post .(@http:Payload AggregatePublishRequest request)
            returns AggregatePublishResponse|http:InternalServerError {
        string[]|error messageIds = publishAggregateBatch(request.aggregates);
        if messageIds is error {
            return {
                body: {
                    message: string `Failed to publish aggregate record batch: ${messageIds.message()}`
                }
            };
        }
        return {messageIds: messageIds};
    }
}
