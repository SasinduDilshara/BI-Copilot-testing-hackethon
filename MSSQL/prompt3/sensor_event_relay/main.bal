
import ballerina/log;
import ballerinax/cdc;

service on plantSensorEventsListener {

    remote function onCreate(SensorEventChange afterEntry, string sourceTableName) returns error? {
        check forwardSensorEvent(afterEntry, sourceTableName);
    }

    remote function onUpdate(SensorEventChange beforeEntry, SensorEventChange afterEntry, string sourceTableName) returns error? {
        check forwardSensorEvent(afterEntry, sourceTableName);
    }

    remote function onRead(SensorEventChange afterEntry, string sourceTableName) returns error? {
        check forwardSensorEvent(afterEntry, sourceTableName);
    }

    remote function onDelete(SensorEventChange beforeEntry, string sourceTableName) returns error? {
        // Sensor events are not forwarded on delete; nothing to relay to analytics.
    }

    remote function onError(cdc:Error cdcError) {
        log:printError("CDC event processing failed", 'error = cdcError);
    }
}
