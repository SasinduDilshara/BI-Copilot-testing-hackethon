import ballerina/time;

# Payload exactly as the edge gateway sends it. We do not control this shape.
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
