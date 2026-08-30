import ballerina/log;
import ballerina/task;
import ballerinax/kafka;

// Recurring job that closes the current tumbling window on every tick,
// publishing aggregates and buffering any threshold alerts they trigger.
class WindowFlushJob {
    *task:Job;

    public function execute() {
        flushWindowAndPublish();
    }
}

// Recurring job that drains the bounded alert buffer and publishes each
// pending alert, running independently of the ingestion and window-flush
// paths so a slow or failing publish never stalls either of them.
class AlertBufferDrainJob {
    *task:Job;

    public function execute() {
        drainAndPublishAlerts();
    }
}

public function main() returns error? {
    task:JobId _ = check task:scheduleJobRecurByFrequency(new WindowFlushJob(), windowSizeSeconds);
    task:JobId _ = check task:scheduleJobRecurByFrequency(new AlertBufferDrainJob(), 1);
    log:printInfo("Started telemetry aggregation window flush and alert buffer drain jobs",
            windowIntervalSeconds = windowSizeSeconds);
}

service kafka:Service on telemetryIngestionListener {

    remote function onConsumerRecord(kafka:Caller caller, TelemetryReadingConsumerRecord[] records) returns error? {
        foreach TelemetryReadingConsumerRecord telemetryRecord in records {
            windowAggregator.addReading(telemetryRecord.value);
        }

        kafka:Error? commitResult = caller->commit();
        if commitResult is kafka:Error {
            log:printError("Failed to commit offsets for the processed batch", 'error = commitResult);
            return commitResult;
        }
        log:printInfo("Successfully ingested telemetry batch", batchSize = records.length());
    }

    remote function onError(kafka:Error err) returns error? {
        log:printError("Error while consuming device telemetry events", 'error = err);
    }
}
