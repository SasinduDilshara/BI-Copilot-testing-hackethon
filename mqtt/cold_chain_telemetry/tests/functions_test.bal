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
