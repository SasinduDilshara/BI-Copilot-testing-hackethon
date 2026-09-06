import ballerina/file;
import ballerina/io;
import ballerina/log;

// Guards against a new sweep starting while a previous sweep is still working through a
// backlog of files. When true, the next due trigger is skipped rather than queued.
boolean sweepInProgress = false;

// Set once shutdown has been requested. When true, no new sweep is started, but an
// already-running sweep is left to finish its current batch rather than being cut off.
boolean shuttingDown = false;

// Running totals of files processed and failed since the sweeper started up.
int totalProcessedCount = 0;
int totalFailedCount = 0;

// Atomically checks whether a sweep is already running and, if not, marks one as started.
// Returns false when a previous sweep is still in progress, or shutdown has been requested,
// signalling the caller to skip.
function markSweepStartedIfFree() returns boolean {
    lock {
        if shuttingDown {
            return false;
        }
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

// Requests that no further sweeps be started. Any sweep already in progress is left to run to
// completion.
function requestShutdown() {
    lock {
        shuttingDown = true;
    }
}

// Returns whether a sweep is currently in progress. Used during shutdown to wait for the
// in-flight batch to finish before the process exits.
function isSweepInProgress() returns boolean {
    lock {
        return sweepInProgress;
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
function sweepInboxFolder(string inboxPath, string processedPath, string quarantinePath) {
    file:MetaData[]|file:Error inboxEntries = file:readDir(inboxPath);
    if inboxEntries is file:Error {
        log:printError(string `Failed to read inbox folder ${inboxPath}, skipping this sweep`, 'error = inboxEntries);
        return;
    }

    foreach file:MetaData entry in inboxEntries {
        if entry.dir {
            continue;
        }
        boolean succeeded = processInboxFile(entry.absPath, processedPath, quarantinePath);
        recordOutcome(succeeded);
    }

    SweepCounters sweepCounters = getSweepCounters();
    log:printInfo(string `Sweep complete. Total processed: ${sweepCounters.processedCount}, total failed: ${
        sweepCounters.failedCount}`);
}

// Processes a single file from the inbox: counts its data rows, logs a one-line summary, and
// moves it into the processed folder. If the file cannot be read, or the single attempt to
// move it fails, it is flagged in the log and, when possible, placed into the quarantine
// folder instead so the rest of the batch can carry on. Returns true on success.
function processInboxFile(string sourceFilePath, string processedPath, string quarantinePath) returns boolean {
    string[][]|error rows = io:fileReadCsv(sourceFilePath);
    if rows is error {
        log:printError(string `Could not read file ${sourceFilePath} as CSV, quarantining it`, 'error = rows);
        quarantineFile(sourceFilePath, quarantinePath);
        return false;
    }
    int dataRowCount = rows.length() > 0 ? rows.length() - 1 : 0;

    string|error fileName = file:basename(sourceFilePath);
    if fileName is error {
        log:printError(string `Could not resolve file name for ${sourceFilePath}, quarantining it`,
                'error = fileName);
        quarantineFile(sourceFilePath, quarantinePath);
        return false;
    }

    string|error destinationFilePath = file:joinPath(processedPath, fileName);
    if destinationFilePath is error {
        log:printError(string `Could not build destination path for ${fileName}, quarantining it`,
                'error = destinationFilePath);
        quarantineFile(sourceFilePath, quarantinePath);
        return false;
    }

    file:Error? moveResult = file:rename(sourceFilePath, destinationFilePath);
    if moveResult is file:Error {
        log:printError(string `Failed to move file ${fileName} into the processed folder, quarantining it`,
                'error = moveResult);
        quarantineFile(sourceFilePath, quarantinePath);
        return false;
    }

    log:printInfo(string `Processed file ${fileName}: ${dataRowCount} data row(s)`);
    return true;
}

// Attempts to move a problem file into the quarantine folder, one attempt only, leaving the
// file where it is and logging the failure if even that cannot be done.
function quarantineFile(string sourceFilePath, string quarantinePath) {
    string|error fileName = file:basename(sourceFilePath);
    if fileName is error {
        log:printError(string `Could not resolve file name for ${sourceFilePath}, leaving it in place`,
                'error = fileName);
        return;
    }

    string|error destinationFilePath = file:joinPath(quarantinePath, fileName);
    if destinationFilePath is error {
        log:printError(string `Could not build quarantine path for ${fileName}, leaving it in place`,
                'error = destinationFilePath);
        return;
    }

    file:Error? moveResult = file:rename(sourceFilePath, destinationFilePath);
    if moveResult is file:Error {
        log:printError(string `Failed to quarantine file ${fileName}, leaving it in place`, 'error = moveResult);
    }
}
