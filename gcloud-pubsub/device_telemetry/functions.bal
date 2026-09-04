import ballerina/log;
import ballerinax/gcloud.pubsub;

// Represents the payload body published to Pub/Sub, excluding the fields
// that are carried as message attributes (deviceId, site, metricName).
type DeviceReadingPayload record {|
    decimal value;
    string unit;
    string recordedAt;
|};

// Raised when storing a reading fails due to a transient condition (e.g. a
// temporary connectivity issue) where redelivery is expected to succeed.
type TransientStorageError distinct error;

// In-memory store standing in for the real persistence layer. Keyed by
// deviceId + recordedAt so re-processing the same reading is idempotent.
final map<DeviceReading> storedReadings = {};

// Builds the message attributes map for a device reading, carrying the
// device ID, site and metric name out-of-band from the payload.
function buildReadingAttributes(DeviceReading reading) returns map<string> => {
    "deviceId": reading.deviceId,
    "site": reading.site,
    "metricName": reading.metricName
};

// Builds the JSON payload body for a device reading, excluding the fields
// that are already carried as message attributes.
function buildReadingPayload(DeviceReading reading) returns DeviceReadingPayload => {
    value: reading.value,
    unit: reading.unit,
    recordedAt: reading.recordedAt
};

// Publishes a device reading to the configured Pub/Sub topic and logs the
// message ID returned by the broker.
function publishDeviceReading(DeviceReading reading) returns error? {
    map<string> attributes = buildReadingAttributes(reading);
    DeviceReadingPayload payload = buildReadingPayload(reading);
    byte[] data = payload.toJsonString().toBytes();

    pubsub:Message message = {
        data: data,
        attributes: attributes,
        orderingKey: reading.deviceId
    };

    string messageId = check telemetryPublisher->publish(message);
    log:printInfo("Published device reading", messageId = messageId, deviceId = reading.deviceId,
            site = reading.site, metricName = reading.metricName);
}

// Reconstructs a DeviceReading from a received Pub/Sub message, reading the
// device ID, site and metric name back out of the attributes.
function toDeviceReading(pubsub:Message message) returns DeviceReading|error {
    map<string>? attributes = message.attributes;
    if attributes is () {
        return error("message is missing required attributes");
    }

    string? deviceId = attributes["deviceId"];
    string? site = attributes["site"];
    string? metricName = attributes["metricName"];
    if deviceId is () || site is () || metricName is () {
        return error("message is missing deviceId, site or metricName attribute");
    }

    string payloadText = check string:fromBytes(message.data);
    DeviceReadingPayload payload = check payloadText.fromJsonStringWithType(DeviceReadingPayload);

    return {
        deviceId,
        site,
        metricName,
        value: payload.value,
        unit: payload.unit,
        recordedAt: payload.recordedAt
    };
}

// Builds the storage key for a reading. Using deviceId + recordedAt makes
// storing a redelivered reading idempotent.
function readingStorageKey(DeviceReading reading) returns string =>
    string:'join("|", reading.deviceId, reading.recordedAt);

// Device ID reserved for exercising the transient-failure/nack path in tests;
// storage always fails transiently for readings with this device ID.
const string TRANSIENT_FAILURE_TEST_DEVICE_ID = "test-transient-failure-device";

// Persists a device reading. Any other error is treated as permanent.
function storeDeviceReading(DeviceReading reading) returns TransientStorageError? {
    if reading.deviceId == TRANSIENT_FAILURE_TEST_DEVICE_ID {
        return error TransientStorageError("simulated transient storage failure");
    }

    string key = readingStorageKey(reading);
    lock {
        storedReadings[key] = reading.clone();
    }
    log:printInfo("Stored device reading", deviceId = reading.deviceId, recordedAt = reading.recordedAt);
}

// Returns the reading stored for the given device ID and timestamp, if any.
function getStoredReading(string deviceId, string recordedAt) returns DeviceReading? {
    string key = string:'join("|", deviceId, recordedAt);
    lock {
        return storedReadings[key];
    }
}
