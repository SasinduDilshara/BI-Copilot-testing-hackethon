import ballerina/lang.runtime;
import ballerina/log;
import ballerina/task;

// Background job that sweeps the inbox folder on every trigger, continuously from the moment
// the process starts until it is stopped. If a previous sweep is still working through a
// backlog when this fires, that turn is skipped and logged instead of a second sweep starting
// on top of the first.
class InboxSweepJob {
    *task:Job;

    public function execute() {
        boolean canRun = markSweepStartedIfFree();
        if !canRun {
            log:printWarn("Skipped this sweep because the previous sweep is still in progress");
            return;
        }

        sweepInboxFolder(inboxFolderPath, processedFolderPath, quarantineFolderPath);

        markSweepFinished();
    }
}

function init() returns error? {
    runtime:onGracefulStop(onShutdown);
    _ = check task:scheduleJobRecurByFrequency(new InboxSweepJob(), sweepIntervalSeconds,
            taskPolicy = {errorPolicy: task:LOG_AND_CONTINUE});
}

// Called when the process is asked to shut down. Stops any further sweeps from starting, then
// waits for a sweep that is already in progress to finish its current batch before allowing
// the process to exit.
function onShutdown() returns error? {
    log:printInfo("Shutdown requested, no new sweeps will be started");
    requestShutdown();

    while isSweepInProgress() {
        log:printInfo("Waiting for the in-progress sweep to finish before shutting down");
        runtime:sleep(1);
    }

    log:printInfo("Shutdown complete");
}
