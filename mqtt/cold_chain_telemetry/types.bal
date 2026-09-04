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
