import ballerina/log;
import ballerina/task;

// Background job that sweeps the inbox folder on every trigger. If a previous sweep is still
// working through a backlog when this fires, that turn is skipped and logged instead of a
// second sweep starting on top of the first.
class InboxSweepJob {
    *task:Job;

    public function execute() {
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
    _ = check task:scheduleJobRecurByFrequency(new InboxSweepJob(), sweepIntervalSeconds,
            taskPolicy = {errorPolicy: task:LOG_AND_CONTINUE});
}
