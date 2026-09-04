import ballerina/lang.regexp;

// Matches ISO 8601 timestamps such as 2026-09-04T03:54:49Z or with offsets.
final regexp:RegExp isoTimestampPattern = check regexp:fromString("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$");

# Tracks the latest vibration and runtime readings per plant and machine in a concurrency-safe manner.
public isolated class MachineStateStore {
    private map<MachineState> statesByMachineKey = {};

    # Records the latest vibration reading for the reading's plant and machine.
    #
    # + reading - The parsed vibration reading
    public isolated function recordVibrationReading(VibrationReading reading) {
        string machineKey = buildMachineKey(reading.plantId, reading.machineId);
        lock {
            MachineState currentState = self.statesByMachineKey[machineKey] ?: {
                plantId: reading.plantId,
                machineId: reading.machineId
            };
            currentState.latestVibration = reading.clone();
            self.statesByMachineKey[machineKey] = currentState;
        }
    }

    # Records the latest runtime reading for the reading's plant and machine.
    #
    # + reading - The parsed runtime reading
    public isolated function recordRuntimeReading(RuntimeReading reading) {
        string machineKey = buildMachineKey(reading.plantId, reading.machineId);
        lock {
            MachineState currentState = self.statesByMachineKey[machineKey] ?: {
                plantId: reading.plantId,
                machineId: reading.machineId
            };
            currentState.latestRuntime = reading.clone();
            self.statesByMachineKey[machineKey] = currentState;
        }
    }

    # Returns a snapshot of the latest known state for a given plant and machine, if any.
    #
    # + plantId - The plant identifier
    # + machineId - The machine identifier
    # + return - A clone of the current MachineState, or () if no readings have been recorded yet
    public isolated function getState(string plantId, string machineId) returns MachineState? {
        string machineKey = buildMachineKey(plantId, machineId);
        lock {
            MachineState? currentState = self.statesByMachineKey[machineKey];
            return currentState is MachineState ? currentState.clone() : ();
        }
    }
}

# Builds the internal map key used to track machine state by plant and machine identifiers.
#
# + plantId - The plant identifier
# + machineId - The machine identifier
# + return - The composite machine state key
public isolated function buildMachineKey(string plantId, string machineId) returns string {
    return string `${plantId}::${machineId}`;
}

# Extracts the plantId and machineId path segments from a fleet sensor topic such as
# plant/{plantId}/machines/{machineId}/vibration or plant/{plantId}/machines/{machineId}/runtime.
#
# + topic - The MQTT topic the message was delivered on
# + return - A tuple of [plantId, machineId], or an error if the topic does not match the expected shape
public isolated function extractPlantAndMachineIds(string topic) returns [string, string]|error {
    string[] segments = regexp:split(re `/`, topic);
    if segments.length() != 5 || segments[0] != "plant" || segments[2] != "machines" {
        return error(string `Malformed sensor topic: '${topic}' does not match the expected plant/{plantId}/machines/{machineId}/{sensorType} shape`);
    }

    string plantId = segments[1];
    string machineId = segments[3];
    if plantId.trim().length() == 0 || machineId.trim().length() == 0 {
        return error(string `Malformed sensor topic: '${topic}' contains empty plantId or machineId`);
    }

    return [plantId, machineId];
}

# Validates that a recordedAt value is a well-formed ISO 8601 timestamp.
#
# + recordedAt - The timestamp string to validate
# + return - true if the timestamp is a valid ISO 8601 timestamp
public isolated function isValidTimestamp(string recordedAt) returns boolean {
    return isoTimestampPattern.isFullMatch(recordedAt);
}

# Parses and validates a raw MQTT payload into a typed VibrationReading, using the plantId and
# machineId extracted from the topic. Rejects payloads that are not valid JSON, are missing
# required fields, have the wrong field types, or contain an invalid recordedAt timestamp.
#
# + payload - Raw MQTT message payload bytes
# + plantId - The plant identifier extracted from the topic
# + machineId - The machine identifier extracted from the topic
# + return - The parsed VibrationReading, or an error if the payload is malformed
public isolated function parseVibrationReading(byte[] payload, string plantId, string machineId) returns VibrationReading|error {
    string payloadText = check string:fromBytes(payload);
    json payloadJson = check payloadText.fromJsonString();
    record {| decimal vibrationMm; string recordedAt; |} body =
        check payloadJson.cloneWithType();

    string recordedAt = body.recordedAt;
    if !isValidTimestamp(recordedAt) {
        return error("Malformed vibration reading: recordedAt must be a valid ISO 8601 timestamp");
    }

    return {
        plantId,
        machineId,
        vibrationMm: body.vibrationMm,
        recordedAt
    };
}

# Parses and validates a raw MQTT payload into a typed RuntimeReading, using the plantId and
# machineId extracted from the topic. Rejects payloads that are not valid JSON, are missing
# required fields, have the wrong field types, or contain an invalid recordedAt timestamp.
#
# + payload - Raw MQTT message payload bytes
# + plantId - The plant identifier extracted from the topic
# + machineId - The machine identifier extracted from the topic
# + return - The parsed RuntimeReading, or an error if the payload is malformed
public isolated function parseRuntimeReading(byte[] payload, string plantId, string machineId) returns RuntimeReading|error {
    string payloadText = check string:fromBytes(payload);
    json payloadJson = check payloadText.fromJsonString();
    record {| decimal runtimeHours; string recordedAt; |} body =
        check payloadJson.cloneWithType();

    string recordedAt = body.recordedAt;
    if !isValidTimestamp(recordedAt) {
        return error("Malformed runtime reading: recordedAt must be a valid ISO 8601 timestamp");
    }

    return {
        plantId,
        machineId,
        runtimeHours: body.runtimeHours,
        recordedAt
    };
}

# Determines whether a vibration reading breaches the configured maximum vibration threshold.
#
# + reading - The parsed vibration reading
# + maxVibrationThresholdMm - The configured maximum allowed vibration in millimeters
# + return - true if the reading breaches the given maximum allowed vibration
public isolated function isVibrationBreach(VibrationReading reading, decimal maxVibrationThresholdMm) returns boolean {
    return reading.vibrationMm > maxVibrationThresholdMm;
}

# Determines whether a runtime reading breaches the configured maximum runtime threshold.
#
# + reading - The parsed runtime reading
# + maxRuntimeThresholdHours - The configured maximum allowed runtime in hours
# + return - true if the reading breaches the given maximum allowed runtime
public isolated function isRuntimeBreach(RuntimeReading reading, decimal maxRuntimeThresholdHours) returns boolean {
    return reading.runtimeHours > maxRuntimeThresholdHours;
}

# Builds the maintenance alert topic for a given plant.
#
# + plantId - The plant identifier
# + return - The fully qualified maintenance alert topic
public isolated function buildMaintenanceAlertTopic(string plantId) returns string {
    return string `plant/${plantId}/maintenance`;
}

# Builds a MaintenanceAlert from a breaching vibration reading.
#
# + reading - The parsed vibration reading that breached the threshold
# + maxVibrationThresholdMm - The configured maximum vibration threshold that was breached
# + return - The constructed MaintenanceAlert
public isolated function buildVibrationAlert(VibrationReading reading, decimal maxVibrationThresholdMm) returns MaintenanceAlert => {
    plantId: reading.plantId,
    machineId: reading.machineId,
    sensorType: "vibration",
    value: reading.vibrationMm,
    thresholdValue: maxVibrationThresholdMm,
    recordedAt: reading.recordedAt,
    message: string `Machine ${reading.machineId} in plant ${reading.plantId} recorded vibration of ${reading.vibrationMm}mm, exceeding the allowed maximum of ${maxVibrationThresholdMm}mm`
};

# Builds a MaintenanceAlert from a breaching runtime reading.
#
# + reading - The parsed runtime reading that breached the threshold
# + maxRuntimeThresholdHours - The configured maximum runtime threshold that was breached
# + return - The constructed MaintenanceAlert
public isolated function buildRuntimeAlert(RuntimeReading reading, decimal maxRuntimeThresholdHours) returns MaintenanceAlert => {
    plantId: reading.plantId,
    machineId: reading.machineId,
    sensorType: "runtime",
    value: reading.runtimeHours,
    thresholdValue: maxRuntimeThresholdHours,
    recordedAt: reading.recordedAt,
    message: string `Machine ${reading.machineId} in plant ${reading.plantId} recorded runtime of ${reading.runtimeHours} hours, exceeding the allowed maximum of ${maxRuntimeThresholdHours} hours`
};
