import ballerina/time;

# Payload exactly as the edge gateway sends it. We do not control this shape.
# observedAt is an RFC 3339 timestamp that may carry sub-second precision
# (e.g. "2024-01-01T12:00:00.023456Z"); it must be parsed and compared at
# full precision, not truncated to whole seconds.
public type GatewayReading record {|
    string deviceId;
    string observedAt;
    decimal value;
    string unit;
|};

# Internal model. Everything downstream assumes a UTC instant.
public type Reading record {|
    string deviceId;
    time:Utc observedAt;
    decimal value;
    string unit;
|};

public type DeviceState record {|
    string deviceId;
    time:Utc lastSeen;
    int readingCount;
    boolean stale;
|};

public type IngestResult record {|
    int accepted;
    int rejected;
|};
