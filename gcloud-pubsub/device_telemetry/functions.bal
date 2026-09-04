import ballerina/log;
import ballerinax/gcloud.pubsub;

// Represents the payload body published to Pub/Sub, excluding the fields
// that are carried as message attributes (deviceId, site, metricName).
type DeviceReadingPayload record {|
    decimal value;
    string unit;
    string recordedAt;
|};

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
        attributes: attributes
    };

    string messageId = check telemetryPublisher->publish(message);
    log:printInfo("Published device reading", messageId = messageId, deviceId = reading.deviceId,
            site = reading.site, metricName = reading.metricName);
}
