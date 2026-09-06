// Represents a single telemetry reading captured from a device.
public type DeviceReading record {|
    string deviceId;
    string site;
    string metricName;
    decimal value;
    string unit;
    string recordedAt;
|};

// Health snapshot exposing how many readings were dropped per region because
// the region was not on the configured allow list.
public type TelemetryHealth record {|
    map<int> droppedReadingCountsByRegion;
|};
