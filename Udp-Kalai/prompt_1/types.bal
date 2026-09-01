// Represents a parsed sensor reading received via UDP.
public type SensorReading record {|
    string sensorId;
    string sensorType;
    decimal value;
    string unit;
    string timestamp;
|};
