import ballerina/tcp;

configurable decimal outboundWriteTimeout = 300;

// Registry of connected device callers keyed by deviceId.
isolated map<tcp:Caller> deviceCallerRegistry = {};

// Registry of device metadata keyed by deviceId.
isolated map<DeviceInfo> deviceInfoRegistry = {};

// Latest telemetry readings keyed by deviceId, then by metric name.
isolated map<map<TelemetryReading>> deviceTelemetryRegistry = {};

// Command history keyed by deviceId, capped at the last 50 commands per device.
isolated map<CommandRecord[]> deviceCommandHistoryRegistry = {};

// Client configuration applied to any outbound tcp:Client connections.
final tcp:ClientConfiguration outboundTcpClientConfig = {
    writeTimeout: outboundWriteTimeout
};
