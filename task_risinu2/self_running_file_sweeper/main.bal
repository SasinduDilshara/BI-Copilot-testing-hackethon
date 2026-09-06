import ballerina/log;
import ballerina/task;
import ballerina/time;

// Background job that sweeps the inbox folder on every trigger. If a previous sweep is still
// working through a backlog when this fires, that turn is skipped and logged instead of a
// second sweep starting on top of the first. The scheduler only fires triggers within the
// configured processing window, but the current time is also checked defensively here in
// case a trigger for the tail end of the window is still in flight after it has closed.
class InboxSweepJob {
    *task:Job;

    private final time:Utc windowEndUtc;

    function init(time:Utc windowEndUtc) {
        self.windowEndUtc = windowEndUtc;
    }

    public function execute() {
        time:Utc now = time:utcNow();
        if time:utcDiffSeconds(self.windowEndUtc, now) <= 0d {
            log:printInfo("Skipped this sweep because the processing window has closed");
            return;
        }

        boolean canRun = markSweepStartedIfFree();
        if !canRun {
            log:printWarn("Skipped this sweep because the previous sweep is still in progress");
            return;
        }

        sweepInboxFolder(inboxFolderPath, processedFolderPath);

        markSweepFinished();
    }
}

function init() returns error? {
    time:Civil windowStart = check time:civilFromString(processingWindowStart);
    time:Civil windowEnd = check time:civilFromString(processingWindowEnd);
    time:Utc windowEndUtc = check time:utcFromCivil(windowEnd);

    _ = check task:scheduleJobRecurByFrequency(new InboxSweepJob(windowEndUtc), sweepIntervalSeconds,
            startTime = windowStart, endTime = windowEnd,
            taskPolicy = {errorPolicy: task:LOG_AND_CONTINUE});
}
