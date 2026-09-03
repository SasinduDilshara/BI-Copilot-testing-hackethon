import ballerina/time;
import ballerina/tcp;
import ballerina/uuid;

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
// Returns the recorded CommandRecord if the device was online and the command was sent, () if the device is offline.
isolated function sendCommandToDevice(string deviceId, "START"|"STOP"|"CONFIGURE"|"RESET" commandType, map<string> parameters) returns CommandRecord?|tcp:Error {
    tcp:Caller? deviceCaller = ();
    lock {
        deviceCaller = deviceCallerRegistry[deviceId];
    }
    if deviceCaller is () {
        return ();
    }
    json parametersJson = parameters.toJson();
    string parametersJsonText = parametersJson.toJsonString();
    string commandMessage = string `CMD|${commandType}|${parametersJsonText}`;
    byte[] commandBytes = commandMessage.toBytes();
    check deviceCaller->writeBytes(commandBytes);
    CommandRecord commandRecord = {
        commandId: uuid:createType4AsString(),
        commandType: commandType,
        parameters: parameters.clone(),
        sentAt: currentTimestamp(),
        acknowledged: false
    };
    appendCommandHistory(deviceId, commandRecord);
    return commandRecord;
}

// Appends a command record to a device's history, keeping only the last 50 entries.
isolated function appendCommandHistory(string deviceId, CommandRecord commandRecord) {
    lock {
        CommandRecord[] history = deviceCommandHistoryRegistry[deviceId] ?: [];
        history.push(commandRecord.clone());
        int maxHistorySize = 50;
        if history.length() > maxHistorySize {
            history = history.slice(history.length() - maxHistorySize);
        }
        deviceCommandHistoryRegistry[deviceId] = history.clone();
    }
}

// Returns the command history for a given device.
isolated function getDeviceCommandHistory(string deviceId) returns CommandRecord[]? {
    lock {
        CommandRecord[]? history = deviceCommandHistoryRegistry[deviceId];
        if history is () {
            return ();
        }
        return history.clone();
    }
}

// Marks a specific command as acknowledged for a device.
// Returns true if the command was found and acknowledged, false if the device or command was not found.
isolated function acknowledgeCommand(string deviceId, string commandId) returns boolean {
    lock {
        CommandRecord[]? history = deviceCommandHistoryRegistry[deviceId];
        if history is () {
            return false;
        }
        boolean found = false;
        foreach int i in 0 ..< history.length() {
            CommandRecord currentRecord = history[i];
            if currentRecord.commandId == commandId {
                CommandRecord updatedRecord = {
                    commandId: currentRecord.commandId,
                    commandType: currentRecord.commandType,
                    parameters: currentRecord.parameters.clone(),
                    sentAt: currentRecord.sentAt,
                    acknowledged: true
                };
                history[i] = updatedRecord;
                found = true;
                break;
            }
        }
        if found {
            deviceCommandHistoryRegistry[deviceId] = history.clone();
        }
        return found;
    }
}
