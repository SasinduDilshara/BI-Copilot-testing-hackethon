import ballerinax/kafka;

// Represents a device telemetry reading decoded from an Avro-encoded message
// on the `iot.telemetry.raw` Kafka topic.
public type TelemetryReading record {|
    string deviceId;
    string siteId;
    string metric;
    decimal value;
    string unit;
    string readingAt;
|};

// Represents a Kafka consumer record whose value is bound to the
// `TelemetryReading` type after Avro deserialization via the schema registry.
public type TelemetryReadingConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    TelemetryReading value;
|};

// Represents the aggregated statistics for one device/metric pair over a
// single closed tumbling window, ready for publishing to
// `iot.telemetry.aggregated`.
public type WindowAggregate record {|
    string deviceId;
    string siteId;
    string metric;
    string unit;
    string windowStart;
    string windowEnd;
    int count;
    decimal min;
    decimal max;
    decimal mean;
|};

// Represents an alert raised because a window's mean for a device/metric pair
// crossed the configured per-metric threshold, ready for publishing to
// `iot.alerts`.
public type TelemetryAlert record {|
    string deviceId;
    string siteId;
    string metric;
    string unit;
    decimal mean;
    decimal threshold;
    string windowStart;
    string windowEnd;
|};

// Mutable, in-progress accumulator for a single device/metric pair within the
// current open window. Not exposed outside the aggregator.
type WindowAccumulator record {|
    string deviceId;
    string siteId;
    string metric;
    string unit;
    int count;
    decimal min;
    decimal max;
    decimal sum;
|};

// Reports the bounded alert buffer's current occupancy, its capacity, and the
// total number of alerts dropped (shed) since startup because the buffer was
// full when a new alert arrived.
public type AlertBufferHealth record {|
    int droppedCount;
    int currentSize;
    int capacity;
|};
