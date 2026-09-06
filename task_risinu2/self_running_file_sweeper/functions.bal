import ballerina/file;
import ballerina/io;
import ballerina/lang.runtime;
import ballerina/log;

// Guards against a new sweep starting while a previous sweep is still working through a
// backlog of files. When true, the next due trigger is skipped rather than queued.
boolean sweepInProgress = false;

// Running totals of files processed and failed since the sweeper started up.
int totalProcessedCount = 0;
int totalFailedCount = 0;

// Maximum number of attempts made to move a file before giving up on it for this sweep.
const int MAX_MOVE_ATTEMPTS = 5;

// The delay, in seconds, before the first retry of a failed file move.
const decimal INITIAL_RETRY_DELAY_SECONDS = 2;

// The delay between successive move attempts is never allowed to exceed this many seconds.
const decimal MAX_RETRY_DELAY_SECONDS = 60;

// Atomically checks whether a sweep is already running and, if not, marks one as started.
// Returns false when a previous sweep is still in progress, signalling the caller to skip.
function markSweepStartedIfFree() returns boolean {
    lock {
        if sweepInProgress {
            return false;
        }
        sweepInProgress = true;
        return true;
    }
}

// Marks the current sweep as finished, allowing the next due trigger to run.
function markSweepFinished() {
    lock {
        sweepInProgress = false;
    }
}

// Records the outcome of processing one file against the running totals.
function recordOutcome(boolean succeeded) {
    lock {
        if succeeded {
            totalProcessedCount += 1;
        } else {
            totalFailedCount += 1;
        }
    }
}

// Returns a snapshot of the running totals of files processed and failed since startup.
function getSweepCounters() returns SweepCounters {
    lock {
        return {processedCount: totalProcessedCount, failedCount: totalFailedCount};
    }
}

// Runs a single sweep of the inbox folder: lists every file present, processes each one in
// turn, and never lets a single bad file stop the rest of the batch from being processed.
// Logs a running-totals summary once the sweep has gone through every file.
function sweepInboxFolder(string inboxPath, string processedPath) {
    file:MetaData[]|file:Error inboxEntries = file:readDir(inboxPath);
    if inboxEntries is file:Error {
        log:printError(string `Failed to read inbox folder ${inboxPath}, skipping this sweep`, 'error = inboxEntries);
        return;
    }

    foreach file:MetaData entry in inboxEntries {
        if entry.dir {
            continue;
        }
        error? processResult = processInboxFile(entry.absPath, processedPath);
        if processResult is error {
            log:printError(string `Failed to process file ${entry.absPath}, leaving it in place`,
                    'error = processResult);
            recordOutcome(false);
        } else {
            recordOutcome(true);
        }
    }

    SweepCounters sweepCounters = getSweepCounters();
    log:printInfo(string `Sweep complete. Total processed: ${sweepCounters.processedCount}, total failed: ${
        sweepCounters.failedCount}`);
}

// Processes a single file from the inbox: counts its data rows, logs a one-line summary, and
// moves it into the processed folder, retrying the move with backoff if it fails transiently.
// Any failure while reading the file or after exhausting the move retries is surfaced to the
// caller as an error so it can be logged and the file left where it is.
function processInboxFile(string sourceFilePath, string processedPath) returns error? {
    string[][] rows = check io:fileReadCsv(sourceFilePath);
    int dataRowCount = rows.length() > 0 ? rows.length() - 1 : 0;

    string fileName = check file:basename(sourceFilePath);
    string destinationFilePath = check file:joinPath(processedPath, fileName);
    check moveFileWithRetry(sourceFilePath, destinationFilePath);

    log:printInfo(string `Processed file ${fileName}: ${dataRowCount} data row(s)`);
}

// Attempts to move a file into the processed folder, retrying with an increasing backoff
// delay when the move fails, since the upstream system may still be writing the file. The
// delay doubles after every attempt but is capped, and the attempt gives up entirely after
// MAX_MOVE_ATTEMPTS tries.
function moveFileWithRetry(string sourceFilePath, string destinationFilePath) returns error? {
    decimal retryDelaySeconds = INITIAL_RETRY_DELAY_SECONDS;

    foreach int attemptNumber in 1 ... MAX_MOVE_ATTEMPTS {
        file:Error? moveResult = file:rename(sourceFilePath, destinationFilePath);
        if moveResult is () {
            return;
        }

        if attemptNumber == MAX_MOVE_ATTEMPTS {
            return error(string `Failed to move file after ${MAX_MOVE_ATTEMPTS} attempts`, moveResult);
        }

        log:printWarn(string `Attempt ${attemptNumber} to move file ${sourceFilePath} failed, retrying in ${
            retryDelaySeconds} second(s)`, 'error = moveResult);
        runtime:sleep(retryDelaySeconds);

        decimal nextRetryDelaySeconds = retryDelaySeconds * 2;
        retryDelaySeconds = nextRetryDelaySeconds < MAX_RETRY_DELAY_SECONDS ? nextRetryDelaySeconds : MAX_RETRY_DELAY_SECONDS;
    }
}
