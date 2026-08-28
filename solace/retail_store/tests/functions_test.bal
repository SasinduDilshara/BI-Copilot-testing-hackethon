import ballerina/test;
import ballerina/time;
import ballerinax/solace;

final DeviceTelemetry sampleFridgeTelemetry = {
    storeId: "store-042",
    region: "us-east",
    deviceType: "fridge",
    deviceId: "fridge-01",
    metric: "temperature",
    value: 9.5d,
    unit: "celsius",
    readingAt: "2026-08-28T03:00:00Z"
};

final DeviceTelemetry sampleUnknownDeviceTelemetry = {
    storeId: "store-042",
    region: "us-east",
    deviceType: "unknown-device",
    deviceId: "unknown-01",
    metric: "signal",
    value: 999.0d,
    unit: "count",
    readingAt: "2026-08-28T03:00:00Z"
};

@test:Config {}
function testIsExpiredFalseWhenExpirationAbsent() {
    test:assertFalse(isExpired(()), msg = "A message without an expiration should not be treated as expired");
}

@test:Config {}
function testIsExpiredFalseWhenExpirationIsZero() {
    test:assertFalse(isExpired(0), msg = "An expiration of zero means the message never expires");
}

@test:Config {}
function testIsExpiredFalseWhenExpirationInFuture() {
    time:Utc futureTime = time:utcAddSeconds(time:utcNow(), 3600);
    int futureMillis = futureTime[0] * 1000;
    test:assertFalse(isExpired(futureMillis), msg = "A future expiration should not be treated as expired");
}

@test:Config {}
function testIsExpiredTrueWhenExpirationInPast() {
    time:Utc pastTime = time:utcAddSeconds(time:utcNow(), -3600);
    int pastMillis = pastTime[0] * 1000;
    test:assertTrue(isExpired(pastMillis), msg = "A past expiration should be treated as expired");
}

@test:Config {}
function testCheckThresholdCrossedReturnsThresholdWhenExceeded() {
    decimal? result = checkThresholdCrossed(sampleFridgeTelemetry);
    test:assertTrue(result is decimal, msg = "A value above the fridge threshold should report the threshold");
    if result is decimal {
        test:assertEquals(result, deviceTypeThresholds.get("fridge"),
                msg = "The reported threshold should match the configured fridge threshold");
    }
}

@test:Config {}
function testCheckThresholdCrossedReturnsNilWhenBelowThreshold() {
    DeviceTelemetry coolFridgeTelemetry = {
        storeId: "store-042",
        region: "us-east",
        deviceType: "fridge",
        deviceId: "fridge-01",
        metric: "temperature",
        value: 4.0d,
        unit: "celsius",
        readingAt: "2026-08-28T03:00:00Z"
    };
    decimal? result = checkThresholdCrossed(coolFridgeTelemetry);
    test:assertTrue(result is (), msg = "A value below the fridge threshold should not cross it");
}

@test:Config {}
function testCheckThresholdCrossedReturnsNilForUnknownDeviceType() {
    decimal? result = checkThresholdCrossed(sampleUnknownDeviceTelemetry);
    test:assertTrue(result is (), msg = "A device type with no configured threshold should never cross");
}

@test:Config {}
function testBuildAlertTopicUsesRegionAndStoreId() {
    string topic = buildAlertTopic(sampleFridgeTelemetry);
    test:assertEquals(topic, "retail/alerts/us-east/store-042", msg = "Unexpected alert topic");
}

@test:Config {}
function testBuildAlertCorrelationPropertiesCarriesStoreIdAndSeverity() {
    map<solace:Property> properties = buildAlertCorrelationProperties(sampleFridgeTelemetry);
    test:assertEquals(properties.get("storeId"), sampleFridgeTelemetry.storeId,
            msg = "storeId should be carried in the correlation properties");
    test:assertEquals(properties.get("severity"), 1, msg = "severity should be carried in the correlation properties");
    test:assertTrue(properties.hasKey("triggeredAt"),
            msg = "triggeredAt should be carried in the correlation properties");
}

@test:Config {}
function testIsRegionAllowedTrueForAllowedRegion() {
    test:assertTrue(isRegionAllowed(sampleFridgeTelemetry),
            msg = "A reading from an allowed region should not be blocked");
}

@test:Config {}
function testIsRegionAllowedFalseForDisallowedRegion() {
    DeviceTelemetry blockedRegionTelemetry = {
        storeId: "store-099",
        region: "ap-south",
        deviceType: "fridge",
        deviceId: "fridge-02",
        metric: "temperature",
        value: 4.0d,
        unit: "celsius",
        readingAt: "2026-08-28T03:00:00Z"
    };
    test:assertFalse(isRegionAllowed(blockedRegionTelemetry),
            msg = "A reading from a region not on the allow list should be blocked");
}

@test:Config {}
function testBufferTelemetryReadingShedsOldestWhenFull() {
    TelemetryHealth beforeHealth = buildTelemetryHealth();

    // Fill the buffer beyond capacity to force at least one shed.
    int overflowCount = telemetryBufferCapacity + 3;
    foreach int i in 0 ..< overflowCount {
        DeviceTelemetry reading = {
            storeId: string `store-${i}`,
            region: "us-east",
            deviceType: "fridge",
            deviceId: string `fridge-${i}`,
            metric: "temperature",
            value: 5.0d,
            unit: "celsius",
            readingAt: "2026-08-28T03:00:00Z"
        };
        bufferTelemetryReading(reading);
    }

    TelemetryHealth afterHealth = buildTelemetryHealth();
    test:assertEquals(afterHealth.bufferedCount, telemetryBufferCapacity,
            msg = "Buffer should never grow beyond its configured capacity");
    test:assertTrue(afterHealth.shedCount > beforeHealth.shedCount,
            msg = "Overflowing the buffer should increment the shed count");
}

