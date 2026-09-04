// Supported sensor reading kinds published by factory machines.
public type SensorType "vibration"|"runtime";

// Represents a parsed vibration reading published by a plant machine.
public type VibrationReading record {|
    string plantId;
    string machineId;
    decimal vibrationMm;
    string recordedAt;
|};

// Represents a parsed runtime reading published by a plant machine.
public type RuntimeReading record {|
    string plantId;
    string machineId;
    decimal runtimeHours;
    string recordedAt;
|};

// Represents the latest known sensor readings for a single machine.
public type MachineState record {|
    string plantId;
    string machineId;
    VibrationReading latestVibration?;
    RuntimeReading latestRuntime?;
|};

// Represents a predictive-maintenance alert published back to the plant maintenance topic.
public type MaintenanceAlert record {|
    string plantId;
    string machineId;
    SensorType sensorType;
    decimal value;
    decimal thresholdValue;
    string recordedAt;
    string message;
|};
