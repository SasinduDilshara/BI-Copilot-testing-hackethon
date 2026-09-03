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

// Command request sent to a device.
public type CommandRequest record {|
    "START"|"STOP"|"CONFIGURE"|"RESET" commandType;
    map<string> parameters;
|};

// Response payload for a successfully dispatched command.
public type CommandSentResponse record {|
    boolean commandSent;
    string deviceId;
|};

// Response payload when the target device is offline.
public type DeviceOfflineResponse record {|
    string status;
|};
