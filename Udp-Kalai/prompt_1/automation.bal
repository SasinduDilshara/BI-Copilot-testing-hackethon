import ballerina/http;

service /sensors on new http:Listener(9001) {

    resource function get .() returns SensorReading[] {
        lock {
            return sensorReadings.toArray().clone();
        }
    }

    resource function get [string sensorId]() returns SensorReading|http:NotFound {
        lock {
            if sensorReadings.hasKey(sensorId) {
                return sensorReadings.get(sensorId).clone();
            }
        }
        return {
            body: string `Sensor reading not found for sensorId: ${sensorId}`
        };
    }
}
