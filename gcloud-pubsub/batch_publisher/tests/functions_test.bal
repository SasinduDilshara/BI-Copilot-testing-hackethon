import ballerina/test;
import ballerinax/gcloud.pubsub;

// Replaces the real publisher construction with a mock client so module
// initialization does not attempt a real Pub/Sub connection when running
// tests.
@test:Mock {
    functionName: "initAggregatePublisher"
}
function mockInitAggregatePublisher() returns pubsub:Publisher|error {
    return test:mock(pubsub:Publisher);
}

AggregateRecord sampleAggregateOne = {
    aggregateId: "aggregate-100",
    metricName: "daily-active-users",
    value: 4210.0,
    periodStart: "2026-09-05T00:00:00Z",
    periodEnd: "2026-09-06T00:00:00Z"
};

AggregateRecord sampleAggregateTwo = {
    aggregateId: "aggregate-101",
    metricName: "daily-revenue",
    value: 987.65,
    periodStart: "2026-09-05T00:00:00Z",
    periodEnd: "2026-09-06T00:00:00Z"
};

@test:Config {}
function testBuildAggregateMessageCarriesRecordAsJsonPayload() returns error? {
    pubsub:Message message = buildAggregateMessage(sampleAggregateOne);

    string payloadText = check string:fromBytes(message.data);
    AggregateRecord rebuilt = check payloadText.fromJsonStringWithType(AggregateRecord);
    test:assertEquals(rebuilt, sampleAggregateOne);
}

@test:Config {}
function testPublishAggregateBatchReturnsMessageIdsInOrder() returns error? {
    string[] mockMessageIds = ["mock-id-1", "mock-id-2"];
    test:prepare(aggregatePublisher).when("publishBatch").thenReturn(mockMessageIds);

    string[]|error messageIds = publishAggregateBatch([sampleAggregateOne, sampleAggregateTwo]);
    test:assertTrue(messageIds is string[]);
    if messageIds is string[] {
        test:assertEquals(messageIds, ["mock-id-1", "mock-id-2"]);
    }
}

@test:Config {}
function testPublishAggregateBatchPropagatesPublisherError() {
    pubsub:Error simulatedError = error("simulated publish failure");
    test:prepare(aggregatePublisher).when("publishBatch").thenReturn(simulatedError);

    string[]|error messageIds = publishAggregateBatch([sampleAggregateOne]);
    test:assertTrue(messageIds is error);
}

@test:Config {}
function testCloseAggregatePublisherSucceedsWithMockPublisher() returns error? {
    test:prepare(aggregatePublisher).when("close").thenReturn(());

    error? result = closeAggregatePublisher();
    test:assertTrue(result is ());
}
