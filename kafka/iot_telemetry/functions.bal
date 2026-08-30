import ballerina/log;

// Parses the "metric=threshold,metric=threshold" configuration string into a
// lookup map. Malformed entries are logged and skipped rather than failing
// startup.
function parseMetricAlertThresholds(string metricAlertThresholdsConfig) returns map<decimal> {
    map<decimal> thresholdsByMetric = {};
    if metricAlertThresholdsConfig.trim().length() == 0 {
        return thresholdsByMetric;
    }
    string[] thresholdEntries = re `,`.split(metricAlertThresholdsConfig);
    foreach string thresholdEntry in thresholdEntries {
        string trimmedEntry = thresholdEntry.trim();
        if trimmedEntry.length() == 0 {
            continue;
        }
        string[] metricAndThreshold = re `=`.split(trimmedEntry);
        if metricAndThreshold.length() != 2 {
            log:printWarn("Skipping malformed metric alert threshold entry", entry = trimmedEntry);
            continue;
        }
        string metricName = metricAndThreshold[0].trim();
        decimal|error thresholdValue = decimal:fromString(metricAndThreshold[1].trim());
        if thresholdValue is error {
            log:printWarn("Skipping metric alert threshold entry with an invalid decimal value",
                    entry = trimmedEntry, 'error = thresholdValue);
            continue;
        }
        thresholdsByMetric[metricName] = thresholdValue;
    }
    return thresholdsByMetric;
}

// Publishes a single closed-window aggregate to `iot.telemetry.aggregated`,
// keyed by deviceId so all windows for a device land on the same partition.
function publishWindowAggregate(WindowAggregate windowAggregate) returns error? {
    check telemetryProducer->send({
        topic: TELEMETRY_AGGREGATED_TOPIC,
        key: windowAggregate.deviceId.toBytes(),
        value: windowAggregate.toJson().toJsonString().toBytes()
    });
}

// Publishes a single threshold-crossing alert to `iot.alerts`, keyed by deviceId.
function publishTelemetryAlert(TelemetryAlert telemetryAlert) returns error? {
    check telemetryProducer->send({
        topic: TELEMETRY_ALERTS_TOPIC,
        key: telemetryAlert.deviceId.toBytes(),
        value: telemetryAlert.toJson().toJsonString().toBytes()
    });
}

// Builds the alert for a window aggregate if, and only if, its mean crosses
// the given threshold for that metric. Metrics without a configured
// threshold never alert. Takes the threshold map as a parameter so the
// threshold-crossing logic can be unit tested independently of configuration.
function buildAlertIfThresholdCrossed(WindowAggregate windowAggregate, map<decimal> thresholdsByMetric)
        returns TelemetryAlert? {
    decimal? threshold = thresholdsByMetric[windowAggregate.metric];
    if threshold is () {
        return ();
    }
    if windowAggregate.mean <= threshold {
        return ();
    }
    return {
        deviceId: windowAggregate.deviceId,
        siteId: windowAggregate.siteId,
        metric: windowAggregate.metric,
        unit: windowAggregate.unit,
        mean: windowAggregate.mean,
        threshold: threshold,
        windowStart: windowAggregate.windowStart,
        windowEnd: windowAggregate.windowEnd
    };
}

// Flushes the current tumbling window, publishes every resulting aggregate,
// and enqueues an alert for any aggregate whose mean crosses its metric's
// threshold. Alerts are buffered rather than published inline so a slow or
// failing alert publish never stalls ingestion for unrelated devices.
function flushWindowAndPublish() {
    map<decimal> thresholdsByMetric = parseMetricAlertThresholds(metricAlertThresholds);
    WindowAggregate[] windowAggregates = windowAggregator.'flush();
    foreach WindowAggregate windowAggregate in windowAggregates {
        error? aggregatePublishResult = publishWindowAggregate(windowAggregate);
        if aggregatePublishResult is error {
            log:printError("Failed to publish window aggregate", 'error = aggregatePublishResult,
                    deviceId = windowAggregate.deviceId, metric = windowAggregate.metric);
        }

        TelemetryAlert? telemetryAlert = buildAlertIfThresholdCrossed(windowAggregate, thresholdsByMetric);
        if telemetryAlert is TelemetryAlert {
            alertBuffer.enqueue(telemetryAlert);
        }
    }
    log:printInfo("Flushed telemetry aggregation window", windowCount = windowAggregates.length());
}

// Drains every alert currently buffered and publishes each to `iot.alerts`.
// Publish failures are logged and the alert is dropped rather than
// re-buffered, since retrying indefinitely would let a persistent failure
// grow the backlog without bound.
function drainAndPublishAlerts() {
    TelemetryAlert[] alertsToPublish = alertBuffer.dequeueAll();
    foreach TelemetryAlert telemetryAlert in alertsToPublish {
        error? alertPublishResult = publishTelemetryAlert(telemetryAlert);
        if alertPublishResult is error {
            log:printError("Failed to publish telemetry alert, dropping it", 'error = alertPublishResult,
                    deviceId = telemetryAlert.deviceId, metric = telemetryAlert.metric);
        }
    }
}
