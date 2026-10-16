// Represents a single vehicle-telemetry reading received from a fleet gateway device.
public type TelemetryReading record {|
    string deviceId;
    decimal latitude;
    decimal longitude;
    string sourceIp;
    json engineMetrics;
    string timestamp;
|};

// Response returned when the ingestion request is accepted for processing.
public type IngestAcknowledgement record {|
    string status;
    int receivedCount;
|};

// Response returned when the request payload fails validation.
public type IngestValidationError record {|
    string message;
|};
