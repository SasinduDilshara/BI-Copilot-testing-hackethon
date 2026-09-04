// Supported sensor reading kinds published by factory machines.
public type SensorType "vibration";

// Represents a parsed vibration reading published by a plant machine.
public type VibrationReading record {|
    string plantId;
    string machineId;
    decimal vibrationMm;
    string recordedAt;
|};

// Represents the latest known sensor readings for a single machine.
public type MachineState record {|
    string plantId;
    string machineId;
    VibrationReading latestVibration?;
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

// Represents a diagnostic request published to a machine when a maintenance alert fires.
public type DiagnosticRequest record {|
    string plantId;
    string machineId;
    SensorType sensorType;
    string correlationId;
|};

// Represents a diagnostic response received back from a machine for a previously published DiagnosticRequest.
public type DiagnosticResponse record {|
    string plantId;
    string machineId;
    string correlationId;
    string status;
    string details?;
|};

// Tracks the lifecycle counters for diagnostic request/response correlation.
public type DiagnosticCounters record {|
    int diagnosticsSent;
    int diagnosticsAnswered;
    int diagnosticsUnanswered;
|};

// Represents an in-flight diagnostic request awaiting a correlated response.
public type PendingDiagnostic record {|
    string plantId;
    string machineId;
    SensorType sensorType;
|};
