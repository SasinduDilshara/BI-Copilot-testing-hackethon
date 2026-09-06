import ballerina/log;
import ballerinax/gcloud.pubsub;

// Consumes device readings from the configured subscription, storing each
// reading before acknowledging it. Acknowledgement only happens after
// successful storage; a transient storage failure triggers a negative
// acknowledgement so the broker redelivers the message.
service on telemetryListener {

    remote function onMessage(pubsub:Message message, pubsub:Caller caller) returns error? {
        check handleIncomingReading(message, caller);
    }
}

// Exposes operational visibility into the telemetry ingestion pipeline.
service /telemetry on telemetryHealthListener {

    resource function get health() returns TelemetryHealth {
        return {
            droppedReadingCountsByRegion: getDroppedReadingCounts()
        };
    }
}

// Processes a single incoming Pub/Sub message: reconstructs the reading,
// stores it, and acks/nacks the caller accordingly. Extracted from the
// service so the acknowledgement behavior can be exercised directly in tests
// with a mocked caller.
function handleIncomingReading(pubsub:Message message, pubsub:Caller caller) returns error? {
    DeviceReading|error reading = toDeviceReading(message);
    if reading is error {
        log:printError("Discarding malformed device reading message", reading);
        check caller->ack();
        return;
    }

    if !isRegionAllowed(reading.site) {
        recordDroppedReading(reading.site);
        log:printWarn("Dropping device reading from a region not on the allow list",
                deviceId = reading.deviceId, site = reading.site);
        check caller->ack();
        return;
    }

    TransientStorageError? storeResult = storeDeviceReading(reading);
    if storeResult is TransientStorageError {
        log:printWarn("Transient failure storing device reading, requesting redelivery",
                storeResult, deviceId = reading.deviceId, recordedAt = reading.recordedAt);
        check caller->nack();
        return;
    }

    check caller->ack();
}
