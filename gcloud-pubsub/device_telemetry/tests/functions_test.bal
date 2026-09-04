import ballerina/test;
import ballerinax/gcloud.pubsub;

// Replaces the real publisher/listener construction with mock clients so
// module initialization does not attempt a real Pub/Sub connection when
// running tests.
@test:Mock {
    functionName: "initTelemetryPublisher"
}
function mockInitTelemetryPublisher() returns pubsub:Publisher|error {
    return test:mock(pubsub:Publisher);
}

@test:Mock {
    functionName: "initTelemetryListener"
}
function mockInitTelemetryListener() returns pubsub:Listener|error {
    pubsub:Listener mockListener = test:mock(pubsub:Listener);
    test:prepare(mockListener).when("attach").thenReturn(());
    test:prepare(mockListener).when("detach").thenReturn(());
    test:prepare(mockListener).when("start").thenReturn(());
    test:prepare(mockListener).when("gracefulStop").thenReturn(());
    test:prepare(mockListener).when("immediateStop").thenReturn(());
    return mockListener;
}

DeviceReading sampleReading = {
    deviceId: "device-001",
    site: "site-central",
    metricName: "temperature",
    value: 23.5,
    unit: "C",
    recordedAt: "2026-09-04T09:40:43Z"
};

@test:Config {}
function testBuildReadingAttributesCarriesRoutingFieldsOnly() {
    map<string> attributes = buildReadingAttributes(sampleReading);

    test:assertEquals(attributes.length(), 3);
    test:assertEquals(attributes["deviceId"], "device-001");
    test:assertEquals(attributes["site"], "site-central");
    test:assertEquals(attributes["metricName"], "temperature");
}

@test:Config {}
function testBuildReadingPayloadExcludesRoutingFields() {
    DeviceReadingPayload payload = buildReadingPayload(sampleReading);

    test:assertEquals(payload.value, 23.5d);
    test:assertEquals(payload.unit, "C");
    test:assertEquals(payload.recordedAt, "2026-09-04T09:40:43Z");
}

@test:Config {}
function testToDeviceReadingRoundTripsAPublishedMessage() returns error? {
    map<string> attributes = buildReadingAttributes(sampleReading);
    DeviceReadingPayload payload = buildReadingPayload(sampleReading);

    pubsub:Message message = {
        data: payload.toJsonString().toBytes(),
        attributes: attributes,
        orderingKey: sampleReading.deviceId
    };

    DeviceReading rebuilt = check toDeviceReading(message);
    test:assertEquals(rebuilt, sampleReading);
}

@test:Config {}
function testToDeviceReadingFailsWhenAttributesMissing() {
    pubsub:Message message = {
        data: "{}".toBytes()
    };

    DeviceReading|error result = toDeviceReading(message);
    test:assertTrue(result is error);
}

@test:Config {}
function testToDeviceReadingFailsWhenARoutingAttributeIsMissing() {
    pubsub:Message message = {
        data: "{\"value\":1.0,\"unit\":\"C\",\"recordedAt\":\"2026-09-04T09:40:43Z\"}".toBytes(),
        attributes: {
            "deviceId": "device-001",
            "site": "site-central"
        }
    };

    DeviceReading|error result = toDeviceReading(message);
    test:assertTrue(result is error);
}

@test:Config {}
function testStoreDeviceReadingPersistsReadingAndIsRetrievable() returns error? {
    DeviceReading reading = {
        deviceId: "device-002",
        site: "site-north",
        metricName: "humidity",
        value: 55.2,
        unit: "%",
        recordedAt: "2026-09-04T10:00:00Z"
    };

    TransientStorageError? result = storeDeviceReading(reading);
    test:assertTrue(result is ());

    DeviceReading? stored = getStoredReading(reading.deviceId, reading.recordedAt);
    test:assertEquals(stored, reading);
}

@test:Config {}
function testStoreDeviceReadingIsIdempotentForRedeliveredMessages() returns error? {
    DeviceReading reading = {
        deviceId: "device-003",
        site: "site-south",
        metricName: "pressure",
        value: 101.3,
        unit: "kPa",
        recordedAt: "2026-09-04T11:00:00Z"
    };

    TransientStorageError? first = storeDeviceReading(reading);
    TransientStorageError? redelivered = storeDeviceReading(reading);
    test:assertTrue(first is ());
    test:assertTrue(redelivered is ());

    DeviceReading? stored = getStoredReading(reading.deviceId, reading.recordedAt);
    test:assertEquals(stored, reading);
}

@test:Config {}
function testPublishDeviceReadingSendsOrderingKeyAndAttributesToMockPublisher() returns error? {
    test:prepare(telemetryPublisher).when("publish").thenReturn("mock-message-id-1");

    error? result = publishDeviceReading(sampleReading);
    test:assertTrue(result is ());
}

@test:Config {}
function testHandleIncomingReadingAcksAfterSuccessfulStorage() returns error? {
    pubsub:Caller mockCaller = test:mock(pubsub:Caller);
    test:prepare(mockCaller).when("ack").thenReturn(());

    map<string> attributes = buildReadingAttributes(sampleReading);
    DeviceReadingPayload payload = buildReadingPayload(sampleReading);
    pubsub:Message message = {
        data: payload.toJsonString().toBytes(),
        attributes: attributes,
        orderingKey: sampleReading.deviceId
    };

    error? result = handleIncomingReading(message, mockCaller);
    test:assertTrue(result is ());

    DeviceReading? stored = getStoredReading(sampleReading.deviceId, sampleReading.recordedAt);
    test:assertEquals(stored, sampleReading);
}

@test:Config {}
function testHandleIncomingReadingAcksMalformedMessageWithoutStoring() returns error? {
    pubsub:Caller mockCaller = test:mock(pubsub:Caller);
    test:prepare(mockCaller).when("ack").thenReturn(());

    pubsub:Message malformedMessage = {
        data: "{}".toBytes()
    };

    error? result = handleIncomingReading(malformedMessage, mockCaller);
    test:assertTrue(result is ());
}

@test:Config {}
function testHandleIncomingReadingNacksOnTransientStorageFailure() returns error? {
    pubsub:Caller mockCaller = test:mock(pubsub:Caller);
    test:prepare(mockCaller).when("nack").thenReturn(());

    DeviceReading failingReading = {
        deviceId: TRANSIENT_FAILURE_TEST_DEVICE_ID,
        site: "site-central",
        metricName: "temperature",
        value: 1.0,
        unit: "C",
        recordedAt: "2026-09-04T12:00:00Z"
    };
    map<string> attributes = buildReadingAttributes(failingReading);
    DeviceReadingPayload payload = buildReadingPayload(failingReading);
    pubsub:Message message = {
        data: payload.toJsonString().toBytes(),
        attributes: attributes,
        orderingKey: failingReading.deviceId
    };

    error? result = handleIncomingReading(message, mockCaller);
    test:assertTrue(result is ());

    DeviceReading? stored = getStoredReading(failingReading.deviceId, failingReading.recordedAt);
    test:assertTrue(stored is ());
}
