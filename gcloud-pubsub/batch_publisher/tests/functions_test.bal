import ballerina/http;
import ballerina/test;
import ballerinax/gcloud.pubsub;

// Replaces the real publisher/REST client construction with mock clients so
// module initialization does not attempt a real Pub/Sub connection or a
// real Google auth token exchange when running tests.
@test:Mock {
    functionName: "initAggregatePublisher"
}
function mockInitAggregatePublisher() returns pubsub:Publisher|error {
    return test:mock(pubsub:Publisher);
}

@test:Mock {
    functionName: "initPubsubRestClient"
}
function mockInitPubsubRestClient() returns http:Client|error {
    return test:mock(http:Client);
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
    test:prepare(aggregatePublisher).when("publishBatch").thenReturn(["mock-id-1", "mock-id-2"]);

    string[]|error messageIds = publishAggregateBatch([sampleAggregateOne, sampleAggregateTwo]);
    test:assertTrue(messageIds is string[]);
    if messageIds is string[] {
        test:assertEquals(messageIds, ["mock-id-1", "mock-id-2"]);
    }
}

@test:Config {}
function testPublishAggregateBatchPropagatesPublisherError() {
    test:prepare(aggregatePublisher).when("publishBatch").thenReturn(error("simulated publish failure"));

    string[]|error messageIds = publishAggregateBatch([sampleAggregateOne]);
    test:assertTrue(messageIds is error);
}

@test:Config {}
function testResolveCredentialsUsesJsonStringWhenAuthModeIsJsonString() {
    pubsub:Credentials credentials = resolveCredentials("jsonString", "unused-path", "{\"type\":\"service_account\"}");
    test:assertEquals(credentials, {credentialsJson: "{\"type\":\"service_account\"}"});
}

@test:Config {}
function testResolveCredentialsUsesFilePathWhenAuthModeIsFilePath() {
    pubsub:Credentials credentials = resolveCredentials("filePath", "/path/to/key.json", "unused-json");
    test:assertEquals(credentials, {credentialsPath: "/path/to/key.json"});
}

@test:Config {}
function testToPulledMessageMapsAllFields() {
    PubSubReceivedMessage received = {
        ackId: "ack-1",
        message: {
            messageId: "msg-1",
            data: "aGVsbG8=",
            attributes: {"source": "test"},
            publishTime: "2026-09-06T17:00:00Z"
        }
    };

    PulledMessage pulled = toPulledMessage(received);
    test:assertEquals(pulled.ackId, "ack-1");
    test:assertEquals(pulled.messageId, "msg-1");
    test:assertEquals(pulled.data, "aGVsbG8=");
    test:assertEquals(pulled.attributes, {"source": "test"});
    test:assertEquals(pulled.publishTime, "2026-09-06T17:00:00Z");
}

@test:Config {}
function testToPulledMessageHandlesMissingOptionalFields() {
    PubSubReceivedMessage received = {
        ackId: "ack-2",
        message: {}
    };

    PulledMessage pulled = toPulledMessage(received);
    test:assertEquals(pulled.ackId, "ack-2");
    test:assertEquals(pulled.messageId, ());
    test:assertEquals(pulled.data, "");
    test:assertEquals(pulled.attributes, {});
    test:assertEquals(pulled.publishTime, ());
}

@test:Config {}
function testPullAggregateMessagesReturnsMappedMessages() returns error? {
    PubSubPullResponse mockResponse = {
        receivedMessages: [
            {
                ackId: "ack-10",
                message: {
                    messageId: "msg-10",
                    data: "cGF5bG9hZA==",
                    attributes: {"aggregateId": "aggregate-100"},
                    publishTime: "2026-09-06T17:05:00Z"
                }
            }
        ]
    };
    test:prepare(pubsubRestClient).when("post").thenReturn(mockResponse);

    PulledMessage[]|error pulledMessages = pullAggregateMessages();
    test:assertTrue(pulledMessages is PulledMessage[]);
    if pulledMessages is PulledMessage[] {
        test:assertEquals(pulledMessages.length(), 1);
        test:assertEquals(pulledMessages[0].ackId, "ack-10");
        test:assertEquals(pulledMessages[0].messageId, "msg-10");
    }
}

@test:Config {}
function testPullAggregateMessagesReturnsEmptyArrayWhenNoMessagesAvailable() returns error? {
    PubSubPullResponse mockResponse = {receivedMessages: []};
    test:prepare(pubsubRestClient).when("post").thenReturn(mockResponse);

    PulledMessage[]|error pulledMessages = pullAggregateMessages();
    test:assertTrue(pulledMessages is PulledMessage[]);
    if pulledMessages is PulledMessage[] {
        test:assertEquals(pulledMessages.length(), 0);
    }
}

@test:Config {}
function testPullAggregateMessagesPropagatesRestClientError() {
    test:prepare(pubsubRestClient).when("post").thenReturn(error("simulated REST pull failure"));

    PulledMessage[]|error pulledMessages = pullAggregateMessages();
    test:assertTrue(pulledMessages is error);
}
