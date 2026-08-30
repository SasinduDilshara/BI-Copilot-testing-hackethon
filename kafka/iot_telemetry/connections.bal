import ballerinax/kafka;

const string TELEMETRY_RAW_TOPIC = "iot.telemetry.raw";
const string TELEMETRY_AGGREGATED_TOPIC = "iot.telemetry.aggregated";
const string TELEMETRY_ALERTS_TOPIC = "iot.alerts";
const string TELEMETRY_INGESTION_GROUP = "telemetry-ingestion";

// Listener for plain JSON telemetry readings. `concurrentConsumers` runs 4
// consumer threads within the same group, spreading the subscribed topic's
// partitions across them.
listener kafka:Listener telemetryIngestionListener = new (kafkaBootstrapServers, {
    groupId: TELEMETRY_INGESTION_GROUP,
    topics: [TELEMETRY_RAW_TOPIC],
    offsetReset: "earliest",
    autoCommit: false,
    pollingInterval: 1,
    concurrentConsumers: 4
});

// Producer used to publish both the per-window aggregates and the threshold
// alerts derived from them.
final kafka:Producer telemetryProducer = check new (kafkaBootstrapServers, {
    clientId: "telemetry-aggregation-producer",
    acks: "all",
    enableIdempotence: true
});

// Aggregates readings per device and metric over the configured tumbling
// window.
final WindowAggregator windowAggregator = new ();

// Bounded buffer of alerts pending publish to `iot.alerts`. Decouples alert
// publishing from ingestion: a slow or failing publish never stalls the
// consumer, and once full, the oldest pending alert is dropped (counted) to
// make room for the newest.
final BoundedAlertBuffer alertBuffer = new (alertBufferCapacity);
