import ballerina/test;

// Builds a valid window aggregate used as the baseline for threshold tests.
function buildWindowAggregate(string metric, decimal mean) returns WindowAggregate => {
    deviceId: "DEV-1",
    siteId: "SITE-1",
    metric: metric,
    unit: "C",
    windowStart: "2026-08-30T05:00:00Z",
    windowEnd: "2026-08-30T05:01:00Z",
    count: 5,
    min: mean - 5.0d,
    max: mean + 5.0d,
    mean: mean
};

@test:Config {}
function testBuildAlertIfThresholdCrossedReturnsAlertWhenMeanExceedsThreshold() {
    map<decimal> thresholdsByMetric = {"temperature": 80.0d};
    WindowAggregate windowAggregate = buildWindowAggregate("temperature", 85.0d);
    TelemetryAlert? telemetryAlert = buildAlertIfThresholdCrossed(windowAggregate, thresholdsByMetric);
    test:assertTrue(telemetryAlert is TelemetryAlert,
            msg = "An alert should be raised when the mean exceeds the configured threshold");
    if telemetryAlert is TelemetryAlert {
        test:assertEquals(telemetryAlert.deviceId, windowAggregate.deviceId, msg = "deviceId should be carried over");
        test:assertEquals(telemetryAlert.metric, windowAggregate.metric, msg = "metric should be carried over");
        test:assertEquals(telemetryAlert.mean, windowAggregate.mean, msg = "mean should be carried over");
        test:assertEquals(telemetryAlert.threshold, 80.0d, msg = "threshold should be the configured metric threshold");
    }
}

@test:Config {}
function testBuildAlertIfThresholdCrossedReturnsNilWhenMeanAtOrBelowThreshold() {
    map<decimal> thresholdsByMetric = {"temperature": 80.0d};
    WindowAggregate windowAggregate = buildWindowAggregate("temperature", 80.0d);
    TelemetryAlert? telemetryAlert = buildAlertIfThresholdCrossed(windowAggregate, thresholdsByMetric);
    test:assertTrue(telemetryAlert is (), msg = "No alert should be raised when the mean does not exceed the threshold");
}

@test:Config {}
function testBuildAlertIfThresholdCrossedReturnsNilForMetricWithoutConfiguredThreshold() {
    map<decimal> thresholdsByMetric = {"temperature": 80.0d};
    WindowAggregate windowAggregate = buildWindowAggregate("vibration", 1000.0d);
    TelemetryAlert? telemetryAlert = buildAlertIfThresholdCrossed(windowAggregate, thresholdsByMetric);
    test:assertTrue(telemetryAlert is (),
            msg = "No alert should be raised for a metric with no configured threshold");
}

// Builds a valid telemetry alert used as the baseline for buffer tests.
function buildTelemetryAlert(string deviceId) returns TelemetryAlert => {
    deviceId: deviceId,
    siteId: "SITE-1",
    metric: "temperature",
    unit: "C",
    mean: 90.0d,
    threshold: 80.0d,
    windowStart: "2026-08-30T05:00:00Z",
    windowEnd: "2026-08-30T05:01:00Z"
};

@test:Config {}
function testBoundedAlertBufferKeepsAllAlertsUnderCapacity() {
    BoundedAlertBuffer boundedAlertBuffer = new (5);
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-1"));
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-2"));

    TelemetryAlert[] drainedAlerts = boundedAlertBuffer.dequeueAll();
    test:assertEquals(drainedAlerts.length(), 2, msg = "Both alerts should be retained when under capacity");
    test:assertEquals(boundedAlertBuffer.getHealth().droppedCount, 0,
            msg = "No alerts should be dropped when under capacity");
}

@test:Config {}
function testBoundedAlertBufferDropsOldestWhenFull() {
    BoundedAlertBuffer boundedAlertBuffer = new (2);
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-1"));
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-2"));
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-3"));

    TelemetryAlert[] drainedAlerts = boundedAlertBuffer.dequeueAll();
    test:assertEquals(drainedAlerts.length(), 2, msg = "The buffer should never exceed its configured capacity");
    test:assertEquals(drainedAlerts[0].deviceId, "DEV-2", msg = "The oldest alert should have been dropped first");
    test:assertEquals(drainedAlerts[1].deviceId, "DEV-3", msg = "The newest alert should be retained");
}

@test:Config {}
function testBoundedAlertBufferCountsDroppedAlerts() {
    BoundedAlertBuffer boundedAlertBuffer = new (1);
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-1"));
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-2"));
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-3"));

    AlertBufferHealth alertBufferHealth = boundedAlertBuffer.getHealth();
    test:assertEquals(alertBufferHealth.droppedCount, 2, msg = "Two alerts should have been dropped beyond capacity 1");
    test:assertEquals(alertBufferHealth.currentSize, 1, msg = "Only one alert should remain buffered");
    test:assertEquals(alertBufferHealth.capacity, 1, msg = "capacity should reflect the configured value");
}

@test:Config {}
function testBoundedAlertBufferDequeueAllClearsBuffer() {
    BoundedAlertBuffer boundedAlertBuffer = new (5);
    boundedAlertBuffer.enqueue(buildTelemetryAlert("DEV-1"));
    TelemetryAlert[] firstDrain = boundedAlertBuffer.dequeueAll();
    test:assertEquals(firstDrain.length(), 1, msg = "First drain should return the buffered alert");

    TelemetryAlert[] secondDrain = boundedAlertBuffer.dequeueAll();
    test:assertEquals(secondDrain.length(), 0, msg = "A second drain with nothing newly enqueued should be empty");
}

@test:Config {}
function testBoundedAlertBufferGetHealthOnEmptyBuffer() {
    BoundedAlertBuffer boundedAlertBuffer = new (10);
    AlertBufferHealth alertBufferHealth = boundedAlertBuffer.getHealth();
    test:assertEquals(alertBufferHealth.droppedCount, 0, msg = "A fresh buffer should report zero drops");
    test:assertEquals(alertBufferHealth.currentSize, 0, msg = "A fresh buffer should report zero current size");
    test:assertEquals(alertBufferHealth.capacity, 10, msg = "capacity should reflect the configured value");
}

