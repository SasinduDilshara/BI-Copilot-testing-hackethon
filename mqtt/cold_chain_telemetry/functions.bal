import ballerina/lang.regexp;

// Matches ISO 8601 timestamps such as 2026-09-04T03:54:49Z or with offsets.
final regexp:RegExp isoTimestampPattern = check regexp:fromString("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$");

# Tracks device health counters for the telemetry service in a concurrency-safe manner.
public isolated class DeviceHealthCounters {
    private int messagesReceived = 0;
    private int messagesRejected = 0;
    private int breachesDetected = 0;
    private int alertsPublished = 0;

    # Increments the count of messages received from the broker.
    public isolated function incrementMessagesReceived() {
        lock {
            self.messagesReceived += 1;
        }
    }

    # Increments the count of messages rejected due to malformed payloads.
    public isolated function incrementMessagesRejected() {
        lock {
            self.messagesRejected += 1;
        }
    }

    # Increments the count of threshold breaches detected.
    public isolated function incrementBreachesDetected() {
        lock {
            self.breachesDetected += 1;
        }
    }

    # Increments the count of alerts successfully published.
    public isolated function incrementAlertsPublished() {
        lock {
            self.alertsPublished += 1;
        }
    }

    # Builds an online DeviceHealth snapshot from the current counter values.
    #
    # + return - The current DeviceHealth snapshot
    public isolated function snapshot() returns DeviceHealth {
        lock {
            return {
                status: "online",
                messagesReceived: self.messagesReceived,
                messagesRejected: self.messagesRejected,
                breachesDetected: self.breachesDetected,
                alertsPublished: self.alertsPublished
            };
        }
    }
}

# Parses and validates a raw MQTT payload into a typed TemperatureReading.
# Rejects payloads that are not valid JSON, are missing required fields,
# have the wrong field types, or contain an invalid recordedAt timestamp.
#
# + payload - Raw MQTT message payload bytes
# + return - The parsed TemperatureReading, or an error if the payload is malformed
public isolated function parseTemperatureReading(byte[] payload) returns TemperatureReading|error {
    string payloadText = check string:fromBytes(payload);
    json payloadJson = check payloadText.fromJsonString();
    TemperatureReading reading = check payloadJson.cloneWithType(TemperatureReading);

    string deviceId = reading.deviceId;
    string cargoId = reading.cargoId;
    if deviceId.trim().length() == 0 || cargoId.trim().length() == 0 {
        return error("Malformed temperature reading: deviceId and cargoId must be non-empty");
    }

    string recordedAt = reading.recordedAt;
    if !isoTimestampPattern.isFullMatch(recordedAt) {
        return error("Malformed temperature reading: recordedAt must be a valid ISO 8601 timestamp");
    }

    return reading;
}

# Determines whether a temperature reading breaches the configured cold-chain threshold.
#
# + reading - The parsed temperature reading
# + return - true if the reading breaches the configured maximum allowed temperature
public isolated function isThresholdBreach(TemperatureReading reading) returns boolean {
    return reading.celsius > maxAllowedCelsius;
}

# Builds the alert topic for a given device.
#
# + deviceId - The device identifier
# + return - The fully qualified alert topic
public isolated function buildAlertTopic(string deviceId) returns string {
    return string `fleet/${deviceId}/alerts`;
}

# Builds a TemperatureAlert from a breaching temperature reading.
#
# + reading - The parsed temperature reading that breached the threshold
# + return - The constructed TemperatureAlert
public isolated function buildTemperatureAlert(TemperatureReading reading) returns TemperatureAlert => {
    deviceId: reading.deviceId,
    cargoId: reading.cargoId,
    celsius: reading.celsius,
    thresholdCelsius: maxAllowedCelsius,
    recordedAt: reading.recordedAt,
    message: string `Cargo ${reading.cargoId} on device ${reading.deviceId} recorded ${reading.celsius}C, exceeding the allowed maximum of ${maxAllowedCelsius}C`
};
