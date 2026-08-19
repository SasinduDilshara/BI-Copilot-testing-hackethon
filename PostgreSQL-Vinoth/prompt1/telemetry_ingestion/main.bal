import ballerina/http;
import ballerina/log;

service /telemetry on new http:Listener(servicePort) {

    # Receives a batched vehicle-telemetry payload from a fleet gateway device and
    # persists each reading into the device_readings table.
    #
    # + readings - JSON array of telemetry readings (device ID, GPS lat/lng, engine-metrics blob, timestamp)
    # + return - acknowledgement on success, validation error on bad input, or an internal server error
    resource function post ingest(@http:Payload TelemetryReading[] readings)
            returns IngestAcknowledgement|IngestValidationError|http:InternalServerError {
        if readings.length() == 0 {
            return <IngestValidationError>{message: "Payload must contain at least one reading"};
        }

        error? persistResult = persistReadings(readings);
        if persistResult is error {
            log:printError("Failed to persist telemetry readings", 'error = persistResult);
            return <http:InternalServerError>{
                body: {message: "Failed to persist telemetry readings"}
            };
        }

        return <IngestAcknowledgement>{status: "accepted", receivedCount: readings.length()};
    }
}
