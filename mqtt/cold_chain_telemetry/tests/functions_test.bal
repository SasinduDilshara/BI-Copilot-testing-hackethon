import ballerina/test;

@test:Config {}
function testParseValidTemperatureReading() returns error? {
    byte[] payload = string `{"deviceId":"dev-1","cargoId":"cargo-1","celsius":4.5,"recordedAt":"2026-09-04T03:54:49Z"}`.toBytes();
    TemperatureReading reading = check parseTemperatureReading(payload);

    test:assertEquals(reading.deviceId, "dev-1", msg = "deviceId should be parsed correctly");
    test:assertEquals(reading.cargoId, "cargo-1", msg = "cargoId should be parsed correctly");
    test:assertEquals(reading.celsius, 4.5d, msg = "celsius should be parsed correctly");
    test:assertEquals(reading.recordedAt, "2026-09-04T03:54:49Z", msg = "recordedAt should be parsed correctly");
}

@test:Config {}
function testParseRejectsInvalidJson() {
    byte[] payload = "not-json".toBytes();
    TemperatureReading|error reading = parseTemperatureReading(payload);
    test:assertTrue(reading is error, msg = "Non-JSON payload should be rejected");
}

@test:Config {}
function testParseRejectsMissingFields() {
    byte[] payload = string `{"deviceId":"dev-1","celsius":4.5}`.toBytes();
    TemperatureReading|error reading = parseTemperatureReading(payload);
    test:assertTrue(reading is error, msg = "Payload missing required fields should be rejected");
}

@test:Config {}
function testParseRejectsEmptyDeviceId() {
    byte[] payload = string `{"deviceId":"","cargoId":"cargo-1","celsius":4.5,"recordedAt":"2026-09-04T03:54:49Z"}`.toBytes();
    TemperatureReading|error reading = parseTemperatureReading(payload);
    test:assertTrue(reading is error, msg = "Payload with empty deviceId should be rejected");
}

@test:Config {}
function testParseRejectsInvalidTimestamp() {
    byte[] payload = string `{"deviceId":"dev-1","cargoId":"cargo-1","celsius":4.5,"recordedAt":"not-a-date"}`.toBytes();
    TemperatureReading|error reading = parseTemperatureReading(payload);
    test:assertTrue(reading is error, msg = "Payload with invalid recordedAt should be rejected");
}

@test:Config {}
function testParseRejectsWrongFieldType() {
    byte[] payload = string `{"deviceId":"dev-1","cargoId":"cargo-1","celsius":"cold","recordedAt":"2026-09-04T03:54:49Z"}`.toBytes();
    TemperatureReading|error reading = parseTemperatureReading(payload);
    test:assertTrue(reading is error, msg = "Payload with wrong celsius type should be rejected");
}

@test:Config {}
function testThresholdBreachDetected() {
    TemperatureReading reading = {
        deviceId: "dev-1",
        cargoId: "cargo-1",
        celsius: 12.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    test:assertTrue(isThresholdBreach(reading), msg = "Reading above max threshold should be a breach");
}

@test:Config {}
function testThresholdNotBreachedWithinLimit() {
    TemperatureReading reading = {
        deviceId: "dev-1",
        cargoId: "cargo-1",
        celsius: 4.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    test:assertFalse(isThresholdBreach(reading), msg = "Reading within max threshold should not be a breach");
}

@test:Config {}
function testBuildAlertTopic() {
    string topic = buildAlertTopic("dev-42");
    test:assertEquals(topic, "fleet/dev-42/alerts", msg = "Alert topic should be built with the device id");
}

@test:Config {}
function testBuildTemperatureAlert() {
    TemperatureReading reading = {
        deviceId: "dev-1",
        cargoId: "cargo-1",
        celsius: 15.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    TemperatureAlert alert = buildTemperatureAlert(reading);

    test:assertEquals(alert.deviceId, "dev-1", msg = "Alert should carry the device id");
    test:assertEquals(alert.cargoId, "cargo-1", msg = "Alert should carry the cargo id");
    test:assertEquals(alert.celsius, 15.0d, msg = "Alert should carry the recorded celsius value");
    test:assertEquals(alert.thresholdCelsius, maxAllowedCelsius, msg = "Alert should carry the configured threshold");
}

@test:Config {}
function testHealthCountersInitialSnapshotIsZeroed() {
    DeviceHealthCounters counters = new;
    DeviceHealth health = counters.snapshot();

    test:assertEquals(health.status, "online", msg = "Fresh counters should report an online status");
    test:assertEquals(health.messagesReceived, 0, msg = "Fresh counters should start with zero messages received");
    test:assertEquals(health.messagesRejected, 0, msg = "Fresh counters should start with zero messages rejected");
    test:assertEquals(health.breachesDetected, 0, msg = "Fresh counters should start with zero breaches detected");
    test:assertEquals(health.alertsPublished, 0, msg = "Fresh counters should start with zero alerts published");
}

@test:Config {}
function testHealthCountersIncrementMessagesReceived() {
    DeviceHealthCounters counters = new;
    counters.incrementMessagesReceived();
    counters.incrementMessagesReceived();
    DeviceHealth health = counters.snapshot();

    test:assertEquals(health.messagesReceived, 2, msg = "messagesReceived should reflect the number of increments");
}

@test:Config {}
function testHealthCountersIncrementMessagesRejected() {
    DeviceHealthCounters counters = new;
    counters.incrementMessagesRejected();
    DeviceHealth health = counters.snapshot();

    test:assertEquals(health.messagesRejected, 1, msg = "messagesRejected should reflect the number of increments");
}

@test:Config {}
function testHealthCountersIncrementBreachesDetected() {
    DeviceHealthCounters counters = new;
    counters.incrementBreachesDetected();
    counters.incrementBreachesDetected();
    counters.incrementBreachesDetected();
    DeviceHealth health = counters.snapshot();

    test:assertEquals(health.breachesDetected, 3, msg = "breachesDetected should reflect the number of increments");
}

@test:Config {}
function testHealthCountersIncrementAlertsPublished() {
    DeviceHealthCounters counters = new;
    counters.incrementAlertsPublished();
    DeviceHealth health = counters.snapshot();

    test:assertEquals(health.alertsPublished, 1, msg = "alertsPublished should reflect the number of increments");
}

@test:Config {}
function testHealthCountersTrackIndependently() {
    DeviceHealthCounters counters = new;
    counters.incrementMessagesReceived();
    counters.incrementMessagesReceived();
    counters.incrementMessagesRejected();
    counters.incrementBreachesDetected();
    counters.incrementAlertsPublished();
    DeviceHealth health = counters.snapshot();

    test:assertEquals(health.messagesReceived, 2, msg = "messagesReceived should be tracked independently");
    test:assertEquals(health.messagesRejected, 1, msg = "messagesRejected should be tracked independently");
    test:assertEquals(health.breachesDetected, 1, msg = "breachesDetected should be tracked independently");
    test:assertEquals(health.alertsPublished, 1, msg = "alertsPublished should be tracked independently");
}
