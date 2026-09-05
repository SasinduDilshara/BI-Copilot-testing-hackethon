import ballerina/log;
import ballerina/task;
import ballerina/time;

// Background job that logs the configured message with a timestamp each time it fires.
// Any failure while doing this work is caught here so the scheduler keeps firing the job
// on its next turn instead of the job being terminated.
class MessageLoggerJob {
    *task:Job;

    private final string message;

    isolated function init(string message) {
        self.message = message;
    }

    public function execute() {
        error? result = self.logMessage();
        if result is error {
            log:printError("Job execution failed, will retry on next trigger", 'error = result);
        }
    }

    private function logMessage() returns error? {
        time:Utc currentUtc = time:utcNow();
        string timestamp = check time:utcToString(currentUtc);
        log:printInfo(string `[${timestamp}] ${self.message}`);
    }
}

// Validates the incoming job request, returning a descriptive error when invalid.
function validateJobRequest(JobRequest jobRequest) returns error? {
    if jobRequest.intervalSeconds <= 0d {
        return error("Interval must be a positive number of seconds");
    }
    if jobRequest.repeatCount <= 0 {
        return error("Repeat count must be a positive integer");
    }
}

// Schedules the recurring background job and returns a generated job identifier.
function scheduleBackgroundJob(JobRequest jobRequest) returns string|error {
    MessageLoggerJob job = new (jobRequest.message);
    task:JobId jobId = check task:scheduleJobRecurByFrequency(
        job,
        jobRequest.intervalSeconds,
        maxCount = jobRequest.repeatCount,
        taskPolicy = {
            errorPolicy: task:LOG_AND_CONTINUE
        }
    );
    return jobId.id.toString();
}
