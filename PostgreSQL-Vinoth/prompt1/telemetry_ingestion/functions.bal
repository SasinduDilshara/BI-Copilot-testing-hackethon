import ballerina/lang.runtime;
import ballerina/log;
import ballerina/sql;

// Builds one parameterized INSERT query per reading, casting the GPS coordinate to a
// native point, the source IP to inet, and the engine-metrics blob to jsonb.
function buildBatchInsertQueries(TelemetryReading[] readings) returns sql:ParameterizedQuery[] {
    sql:ParameterizedQuery[] queries = from TelemetryReading reading in readings
        select `INSERT INTO device_readings (device_id, gps_location, source_ip, engine_metrics, reading_timestamp)
                 VALUES (${reading.deviceId},
                         point(${reading.longitude}, ${reading.latitude}),
                         ${reading.sourceIp}::inet,
                         ${reading.engineMetrics.toJsonString()}::jsonb,
                         ${reading.timestamp}::timestamptz)`;
    return queries;
}

// Persists the raw payload and the failure reason into the dead-letter queue table
// once the batch insert retries have been exhausted.
function writeToDeadLetterQueue(json rawPayload, string errorReason) returns sql:Error? {
    sql:ParameterizedQuery dlqQuery = `INSERT INTO device_readings_dlq (raw_payload, error_reason)
                                        VALUES (${rawPayload.toJsonString()}::jsonb, ${errorReason})`;
    _ = check dbClient->execute(dlqQuery);
}

// Performs the batch insert with retries using exponential backoff. On exhausting all
// retries, the raw payload and the failure reason are written to the DLQ table instead
// of being dropped.
function persistReadingsWithRetry(TelemetryReading[] readings, json rawPayload) returns error? {
    sql:ParameterizedQuery[] batchQueries = buildBatchInsertQueries(readings);
    decimal backoff = initialRetryBackoff;
    int attempt = 0;
    while true {
        sql:ExecutionResult[]|sql:Error batchResult = dbClient->batchExecute(batchQueries);
        if batchResult is sql:ExecutionResult[] {
            return;
        }
        attempt += 1;
        log:printWarn("Batch insert failed", 'error = batchResult, attempt = attempt);
        if attempt >= maxRetryAttempts {
            string errorReason = batchResult.message();
            sql:Error? dlqResult = writeToDeadLetterQueue(rawPayload, errorReason);
            if dlqResult is sql:Error {
                log:printError("Failed to write payload to dead-letter queue", 'error = dlqResult);
                return dlqResult;
            }
            return;
        }
        runtime:sleep(backoff);
        backoff = backoff * 2;
    }
}
