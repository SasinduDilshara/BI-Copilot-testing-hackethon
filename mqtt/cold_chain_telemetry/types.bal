// Represents a parsed temperature reading published by a fleet device.
public type TemperatureReading record {|
    string deviceId;
    string cargoId;
    decimal celsius;
    string recordedAt;
|};

// Represents a threshold breach alert published back to the fleet alerts topic.
public type TemperatureAlert record {|
    string deviceId;
    string cargoId;
    decimal celsius;
    decimal thresholdCelsius;
    string recordedAt;
    string message;
|};

// Represents the retained device health snapshot published for the telemetry service.
public type DeviceHealth record {|
    string status;
    int messagesReceived;
    int messagesRejected;
    int breachesDetected;
    int alertsPublished;
|};
