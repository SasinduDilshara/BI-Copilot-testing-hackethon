import ballerina/tcp;

// Registry of connected device callers keyed by deviceId.
isolated map<tcp:Caller> deviceCallerRegistry = {};

// Registry of device metadata keyed by deviceId.
isolated map<DeviceInfo> deviceInfoRegistry = {};

// Latest telemetry readings keyed by deviceId, then by metric name.
isolated map<map<TelemetryReading>> deviceTelemetryRegistry = {};
