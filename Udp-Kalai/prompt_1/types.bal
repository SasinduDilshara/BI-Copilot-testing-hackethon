// Represents a parsed sensor reading received via UDP.
public type SensorReading record {|
    string sensorId;
    string sensorType;
    decimal value;
    string unit;
    string timestamp;
|};

// Represents a critical alert forwarded to the downstream alert system.
public type AlertPayload record {|
    string sensorId;
    string sensorType;
    decimal value;
    decimal threshold;
    string detectedAt;
|};

// Represents a critical alert event stored in the alert history.
public type AlertEvent record {|
    string sensorId;
    string sensorType;
    decimal value;
    string detectedAt;
    boolean acknowledged;
|};
