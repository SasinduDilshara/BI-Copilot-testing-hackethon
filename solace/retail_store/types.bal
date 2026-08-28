import ballerina/http;
import ballerinax/solace;

# Represents a single device telemetry reading published by a store device onto the
# `retail/telemetry/{region}/{storeId}/{deviceType}` topic hierarchy.
#
# + storeId - Unique identifier of the store the reading originated from
# + region - Region the originating store belongs to
# + deviceType - Category of the device that produced the reading
# + deviceId - Unique identifier of the device that produced the reading
# + metric - Name of the metric being reported
# + value - Measured value of the metric
# + unit - Unit of measure for the reported value
# + readingAt - Timestamp at which the reading was taken
public type DeviceTelemetry record {|
    string storeId;
    string region;
    string deviceType;
    string deviceId;
    string metric;
    decimal value;
    string unit;
    string readingAt;
|};

# Represents a device telemetry message consumed from the durable topic endpoint, narrowed so
# that the `DeviceTelemetry` payload is data-bound directly instead of being delivered as raw
# `anydata`. The `receiveTimestamp` and `expiration` fields are populated because the listener is
# configured with `generateReceiveTimestamps` and `calculateMessageExpiration` enabled.
#
# + payload - The device telemetry reading carried by the message
public type DeviceTelemetryMessage record {|
    *solace:Message;
    DeviceTelemetry payload;
|};

# Represents an error detail payload.
#
# + message - Human readable error description
public type ErrorDetail record {|
    string message;
|};

# Represents a device telemetry alert published when a metric crosses its per-device-type
# threshold.
#
# + storeId - Unique identifier of the store the alert originated from
# + region - Region the originating store belongs to
# + deviceType - Category of the device that produced the reading
# + deviceId - Unique identifier of the device that produced the reading
# + metric - Name of the metric that crossed the threshold
# + value - Measured value that crossed the threshold
# + threshold - Configured threshold for the device type
# + unit - Unit of measure for the reported value
public type DeviceTelemetryAlert record {|
    string storeId;
    string region;
    string deviceType;
    string deviceId;
    string metric;
    decimal value;
    decimal threshold;
    string unit;
|};

# Represents the current state of the bounded telemetry buffer and processing counters.
#
# + bufferedCount - Number of readings currently held in the bounded buffer
# + bufferCapacity - Maximum number of readings the buffer can hold
# + shedCount - Number of readings discarded because the buffer was full when they arrived
# + processedCount - Number of readings processed from the durable topic endpoint subscription
# + skippedExpiredCount - Number of readings dropped because their expiration had already passed
# + blockedRegionCount - Number of readings dropped because their region was not on the
# `allowedRegions` allow list
public type TelemetryHealth record {|
    int bufferedCount;
    int bufferCapacity;
    int shedCount;
    int processedCount;
    int skippedExpiredCount;
    int blockedRegionCount;
|};

# Holds the mutable, in-memory telemetry processing state: the bounded, shed-oldest buffer of
# readings awaiting downstream processing, and the counters surfaced on `GET /telemetry/health`.
# Grouped into a single record so that all fields can be accessed together within one `lock`
# statement.
#
# + telemetryBuffer - Bounded buffer of device telemetry readings awaiting downstream processing
# + shedCount - Number of readings discarded because the buffer was full when they arrived
# + processedCount - Number of readings processed from the durable topic endpoint subscription
# + skippedExpiredCount - Number of readings dropped because their expiration had already passed
# + blockedRegionCount - Number of readings dropped because their region was not on the
# `allowedRegions` allow list
public type TelemetryState record {|
    DeviceTelemetry[] telemetryBuffer;
    int shedCount;
    int processedCount;
    int skippedExpiredCount;
    int blockedRegionCount;
|};

# Represents the response returned for a telemetry health check.
public type TelemetryHealthOk record {|
    *http:Ok;
    TelemetryHealth body;
|};

