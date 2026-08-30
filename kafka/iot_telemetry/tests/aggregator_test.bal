import ballerina/test;

// Builds a valid telemetry reading used as the baseline for aggregation tests.
function buildTelemetryReading(string deviceId, string metric, decimal value) returns TelemetryReading => {
    deviceId: deviceId,
    siteId: "SITE-1",
    metric: metric,
    value: value,
    unit: "C",
    readingAt: "2026-08-30T05:00:00Z"
};

@test:Config {}
function testWindowAggregatorComputesCountMinMaxMeanForSingleDeviceMetric() {
    WindowAggregator aggregator = new ();
    aggregator.addReading(buildTelemetryReading("DEV-1", "temperature", 10.0d));
    aggregator.addReading(buildTelemetryReading("DEV-1", "temperature", 20.0d));
    aggregator.addReading(buildTelemetryReading("DEV-1", "temperature", 30.0d));

    WindowAggregate[] windowAggregates = aggregator.'flush();
    test:assertEquals(windowAggregates.length(), 1, msg = "Expected exactly one aggregate for one device/metric pair");

    WindowAggregate windowAggregate = windowAggregates[0];
    test:assertEquals(windowAggregate.deviceId, "DEV-1", msg = "deviceId should be carried over");
    test:assertEquals(windowAggregate.metric, "temperature", msg = "metric should be carried over");
    test:assertEquals(windowAggregate.siteId, "SITE-1", msg = "siteId should be carried over");
    test:assertEquals(windowAggregate.unit, "C", msg = "unit should be carried over");
    test:assertEquals(windowAggregate.count, 3, msg = "count should reflect the number of readings folded in");
    test:assertEquals(windowAggregate.min, 10.0d, msg = "min should be the smallest reading value");
    test:assertEquals(windowAggregate.max, 30.0d, msg = "max should be the largest reading value");
    test:assertEquals(windowAggregate.mean, 20.0d, msg = "mean should be the average of the reading values");
}

@test:Config {}
function testWindowAggregatorKeepsDeviceAndMetricPairsSeparate() {
    WindowAggregator aggregator = new ();
    aggregator.addReading(buildTelemetryReading("DEV-1", "temperature", 10.0d));
    aggregator.addReading(buildTelemetryReading("DEV-1", "humidity", 40.0d));
    aggregator.addReading(buildTelemetryReading("DEV-2", "temperature", 100.0d));

    WindowAggregate[] windowAggregates = aggregator.'flush();
    test:assertEquals(windowAggregates.length(), 3,
            msg = "Each distinct device/metric pair should produce its own aggregate");

    foreach WindowAggregate windowAggregate in windowAggregates {
        if windowAggregate.deviceId == "DEV-1" && windowAggregate.metric == "temperature" {
            test:assertEquals(windowAggregate.count, 1);
            test:assertEquals(windowAggregate.mean, 10.0d);
        } else if windowAggregate.deviceId == "DEV-1" && windowAggregate.metric == "humidity" {
            test:assertEquals(windowAggregate.count, 1);
            test:assertEquals(windowAggregate.mean, 40.0d);
        } else if windowAggregate.deviceId == "DEV-2" && windowAggregate.metric == "temperature" {
            test:assertEquals(windowAggregate.count, 1);
            test:assertEquals(windowAggregate.mean, 100.0d);
        } else {
            test:assertFail(msg = "Unexpected aggregate produced: " + windowAggregate.toString());
        }
    }
}

@test:Config {}
function testWindowAggregatorFlushResetsStateForNextWindow() {
    WindowAggregator aggregator = new ();
    aggregator.addReading(buildTelemetryReading("DEV-1", "temperature", 10.0d));
    WindowAggregate[] firstWindowAggregates = aggregator.'flush();
    test:assertEquals(firstWindowAggregates.length(), 1, msg = "First window should contain the folded reading");

    WindowAggregate[] secondWindowAggregates = aggregator.'flush();
    test:assertEquals(secondWindowAggregates.length(), 0,
            msg = "A window with no readings should flush to an empty aggregate list");
}

@test:Config {}
function testWindowAggregatorFlushWithNoReadingsProducesNoAggregates() {
    WindowAggregator aggregator = new ();
    WindowAggregate[] windowAggregates = aggregator.'flush();
    test:assertEquals(windowAggregates.length(), 0, msg = "An empty window should produce no aggregates");
}

