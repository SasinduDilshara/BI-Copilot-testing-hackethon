// Kafka broker connection details.
configurable string kafkaBootstrapServers = ?;

// Size of the tumbling aggregation window, in seconds. Readings are grouped
// per device and metric, and each window is flushed on this fixed interval.
configurable decimal windowSizeSeconds = 60;

// Per-metric mean thresholds, as a comma-separated list of "metric=threshold"
// pairs, e.g. "temperature=80.0,humidity=90.0". When a window's mean for a
// metric crosses (strictly exceeds) its configured threshold, an alert is
// published to `iot.alerts`. Metrics without a configured threshold are never
// alerted on.
configurable string metricAlertThresholds = "";

// Maximum number of pending alerts held in the in-memory alert buffer awaiting
// publish to `iot.alerts`. Once full, the oldest buffered alert is dropped to
// make room for the newest one, and the drop is counted rather than stalling
// ingestion for any device.
configurable int alertBufferCapacity = 100;

// HTTP listener port for the telemetry health API.
configurable int telemetryHealthServicePort = 9090;
