
import ballerina/http;
import ballerina/log;

# Derives the plant identifier from the fully qualified table name reported by
# the CDC listener, e.g. `plant_east_db.dbo.sensor_events` -> `plant_east_db`.
function plantFromTableName(string tableName) returns string {
    string[] parts = re `\.`.split(tableName);
    if parts.length() > 0 {
        return parts[0];
    }
    return tableName;
}

# Forwards a captured sensor event to the analytics endpoint, tagging it with
# the originating plant. Failures are logged the same way the previous
# polling-based relay handled them, without stopping the listener.
function forwardSensorEvent(SensorEventChange changeEvent, string tableName) returns error? {
    string plant = plantFromTableName(tableName);
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