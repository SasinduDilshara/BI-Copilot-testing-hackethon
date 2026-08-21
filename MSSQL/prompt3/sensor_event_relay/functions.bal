
import ballerina/http;
import ballerina/log;

# Extracts the source plant database name from the CDC event's own metadata,
# i.e. the fully qualified source table name that Debezium stamps on every
# change event, e.g. `plant_east_db.dbo.sensor_events` -> `plant_east_db`.
# This is per-event metadata, not an assumption about which task or
# connection delivered the event.
function plantFromSourceMetadata(string sourceTableName) returns string {
    string[] parts = re `\.`.split(sourceTableName);
    if parts.length() > 0 {
        return parts[0];
    }
    return sourceTableName;
}

# Forwards a captured sensor event to the analytics endpoint, tagging it with
# the originating plant. Failures are logged the same way the previous
# polling-based relay handled them, without stopping the listener.
function forwardSensorEvent(SensorEventChange changeEvent, string sourceTableName) returns error? {
    string plant = plantFromSourceMetadata(sourceTableName);
    PlantTaggedSensorEvent taggedEvent = {
        eventId: changeEvent.eventId,
        sensorId: changeEvent.sensorId,
        reading: changeEvent.reading,
        recordedAt: changeEvent.recordedAt,
        plant: plant
    };

    http:Response|error response = analyticsClient->post("/sensor-events", taggedEvent);
    if response is error {
        log:printError(string `Relay failed for plant ${plant}`, 'error = response);
        return response;
    }
}