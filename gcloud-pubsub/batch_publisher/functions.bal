import ballerina/log;
import ballerinax/gcloud.pubsub;

// Builds the Pub/Sub message for a single aggregate record, carrying the
// whole record as the JSON payload body.
function buildAggregateMessage(AggregateRecord aggregate) returns pubsub:Message => {
    data: aggregate.toJsonString().toBytes()
};

// Publishes a batch of aggregate records to the configured Pub/Sub topic in
// a single call and returns the broker-assigned message IDs in the same
// order as the submitted records.
function publishAggregateBatch(AggregateRecord[] aggregates) returns string[]|error {
    pubsub:Message[] messages = from AggregateRecord aggregate in aggregates
        select buildAggregateMessage(aggregate);

    string[] messageIds = check aggregatePublisher->publishBatch(messages);
    log:printInfo("Published aggregate record batch", batchSize = messageIds.length());
    return messageIds;
}
