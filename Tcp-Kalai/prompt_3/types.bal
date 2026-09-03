// Metadata about a registered device.
public type DeviceInfo record {|
    string deviceId;
    string deviceType;
    string connectedAt;
    string lastSeenAt;
|};

// Latest telemetry reading for a single metric.
public type TelemetryReading record {|
    string metric;
    decimal value;
    string unit;
    string recordedAt;
|};

// Response payload describing a registered device and its connection status.
public type DeviceStatusInfo record {|
    string deviceId;
    string deviceType;
    string connectedAt;
    string lastSeenAt;
    string status;
|};
