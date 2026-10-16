import ballerina/lang.runtime;
import ballerina/log;
import ballerina/sql;

// Builds a single parameterized INSERT query for one reading, casting the GPS coordinate
// to a native point, the source IP to inet, and the engine-metrics blob to jsonb.
function buildInsertQuery(TelemetryReading reading) returns sql:ParameterizedQuery {
    return `INSERT INTO device_readings (device_id, gps_location, source_ip, engine_metrics, reading_timestamp)
            VALUES (${reading.deviceId},
                    point(${reading.longitude}, ${reading.latitude}),
                    ${reading.sourceIp}::inet,
                    ${reading.engineMetrics.toJsonString()}::jsonb,
                    ${reading.timestamp}::timestamptz)`;
}

// Persists the raw reading and the failure reason into the dead-letter queue table
// once the insert retries for that reading have been exhausted.
function writeToDeadLetterQueue(json rawReading, string errorReason) returns sql:Error? {
    sql:ParameterizedQuery dlqQuery = `INSERT INTO device_readings_dlq (raw_payload, error_reason)
                                        VALUES (${rawReading.toJsonString()}::jsonb, ${errorReason})`;
    _ = check dbClient->execute(dlqQuery);
}

// Inserts a single reading with retries using exponential backoff. On exhausting all
// retries, the raw reading and the failure reason are written to the DLQ table instead
// of being dropped, so a bad row never blocks the other rows in the same payload.
function persistReadingWithRetry(TelemetryReading reading) returns error? {
    sql:ParameterizedQuery insertQuery = buildInsertQuery(reading);
    decimal backoff = initialRetryBackoff;
    int attempt = 0;
    while true {
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(insertQuery);
        if insertResult is sql:ExecutionResult {
            return;
        }
        attempt += 1;
        log:printWarn("Insert failed for reading", 'error = insertResult, deviceId = reading.deviceId, attempt = attempt);
        if attempt >= maxRetryAttempts {
            string errorReason = insertResult.message();
            sql:Error? dlqResult = writeToDeadLetterQueue(reading.toJson(), errorReason);
            if dlqResult is sql:Error {
                log:printError("Failed to write reading to dead-letter queue", 'error = dlqResult, deviceId = reading.deviceId);
                return dlqResult;
            }
            return;
        }
        runtime:sleep(backoff);
        backoff = backoff * 2;
    }
}

// Persists each reading in the payload independently so that a bad row only results in
// that row being dead-lettered, while the remaining good rows in the same payload are
// still attempted and persisted. Processing only aborts if the DLQ write itself fails.
function persistReadings(TelemetryReading[] readings) returns error? {
    foreach TelemetryReading reading in readings {
        error? result = persistReadingWithRetry(reading);
        if result is error {
            return result;
        }
    }
}
