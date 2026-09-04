// Represents a single telemetry reading captured from a device.
public type DeviceReading record {|
    string deviceId;
    string site;
    string metricName;
    decimal value;
    string unit;
    string recordedAt;
|};
