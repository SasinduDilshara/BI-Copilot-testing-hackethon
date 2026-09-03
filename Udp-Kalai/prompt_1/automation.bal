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

    resource function get alerts/history() returns AlertEvent[] {
        lock {
            return alertHistory.clone();
        }
    }

    resource function put alerts/[string sensorId]/acknowledge() returns http:Ok|http:NotFound {
        boolean acknowledged = acknowledgeLatestAlert(sensorId);
        if acknowledged {
            http:Ok okResponse = {
                body: string `Latest alert for sensorId: ${sensorId} acknowledged`
            };
            return okResponse;
        }
        http:NotFound notFoundResponse = {
            body: string `No alert found for sensorId: ${sensorId}`
        };
        return notFoundResponse;
    }
}
