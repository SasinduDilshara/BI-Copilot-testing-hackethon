import ballerina/time;
import ballerina/tcp;

// Builds the current timestamp as a string.
isolated function currentTimestamp() returns string {
    return time:utcToString(time:utcNow());
}

// Registers a newly connected device caller and its metadata.
isolated function registerDevice(string deviceId, string deviceType, tcp:Caller caller) {
    string timestamp = currentTimestamp();
    lock {
        deviceCallerRegistry[deviceId] = caller;
    }
    lock {
        DeviceInfo deviceInfo = {
            deviceId: deviceId,
            deviceType: deviceType,
            connectedAt: timestamp,
            lastSeenAt: timestamp
        };
        deviceInfoRegistry[deviceId] = deviceInfo.clone();
    }
}

// Deregisters a device caller from the registry, keeping device metadata intact.
isolated function deregisterDevice(string deviceId) {
    lock {
        _ = deviceCallerRegistry.removeIfHasKey(deviceId);
    }
}

// Updates the last seen timestamp for a device.
isolated function touchDeviceLastSeen(string deviceId) {
    string timestamp = currentTimestamp();
    lock {
        DeviceInfo? deviceInfo = deviceInfoRegistry[deviceId];
        if deviceInfo is DeviceInfo {
            DeviceInfo updatedInfo = {
                deviceId: deviceInfo.deviceId,
                deviceType: deviceInfo.deviceType,
                connectedAt: deviceInfo.connectedAt,
                lastSeenAt: timestamp
            };
            deviceInfoRegistry[deviceId] = updatedInfo.clone();
        }
    }
}

// Stores the latest telemetry reading for a device metric.
isolated function storeTelemetryReading(string deviceId, string metric, decimal value, string unit) {
    string timestamp = currentTimestamp();
    lock {
        map<TelemetryReading> metricMap = deviceTelemetryRegistry[deviceId] ?: {};
        TelemetryReading reading = {
            metric: metric,
            value: value,
            unit: unit,
            recordedAt: timestamp
        };
        metricMap[metric] = reading.clone();
        deviceTelemetryRegistry[deviceId] = metricMap.clone();
    }
}

// Checks whether a device caller is currently registered (online).
isolated function isDeviceOnline(string deviceId) returns boolean {
    lock {
        return deviceCallerRegistry.hasKey(deviceId);
    }
}

// Returns a snapshot of all registered devices with their connection status.
isolated function getAllDeviceStatuses() returns DeviceStatusInfo[] {
    DeviceInfo[] deviceInfos;
    lock {
        DeviceInfo[] collectedInfos = [];
        foreach DeviceInfo deviceInfo in deviceInfoRegistry {
            collectedInfos.push(deviceInfo.clone());
        }
        deviceInfos = collectedInfos.clone();
    }
    DeviceStatusInfo[] deviceStatuses = [];
    foreach DeviceInfo deviceInfo in deviceInfos {
        boolean online = isDeviceOnline(deviceInfo.deviceId);
        DeviceStatusInfo statusInfo = {
            deviceId: deviceInfo.deviceId,
            deviceType: deviceInfo.deviceType,
            connectedAt: deviceInfo.connectedAt,
            lastSeenAt: deviceInfo.lastSeenAt,
            status: online ? "online" : "offline"
        };
        deviceStatuses.push(statusInfo);
    }
    return deviceStatuses;
}

// Returns the latest telemetry readings for a given device.
isolated function getDeviceTelemetry(string deviceId) returns TelemetryReading[]? {
    map<TelemetryReading> metricMapCopy = {};
    boolean deviceHasTelemetry = false;
    lock {
        map<TelemetryReading>? metricMap = deviceTelemetryRegistry[deviceId];
        if metricMap is map<TelemetryReading> {
            deviceHasTelemetry = true;
            metricMapCopy = metricMap.clone();
        }
    }
    if !deviceHasTelemetry {
        return ();
    }
    TelemetryReading[] readings = [];
    foreach TelemetryReading reading in metricMapCopy {
        readings.push(reading);
    }
    return readings;
}

// Checks whether a device is registered at all (known device, regardless of online status).
isolated function isDeviceKnown(string deviceId) returns boolean {
    lock {
        return deviceInfoRegistry.hasKey(deviceId);
    }
}

// Sends a command to a connected device over its existing TCP connection.
// Returns true if the device was online and the command was sent, false if the device is offline.
isolated function sendCommandToDevice(string deviceId, string commandType, map<string> parameters) returns boolean|tcp:Error {
    tcp:Caller? deviceCaller = ();
    lock {
        deviceCaller = deviceCallerRegistry[deviceId];
    }
    if deviceCaller is () {
        return false;
    }
    json parametersJson = parameters.toJson();
    string parametersJsonText = parametersJson.toJsonString();
    string commandMessage = string `CMD|${commandType}|${parametersJsonText}`;
    byte[] commandBytes = commandMessage.toBytes();
    check deviceCaller->writeBytes(commandBytes);
    return true;
}
