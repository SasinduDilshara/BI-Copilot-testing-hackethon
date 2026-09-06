import ballerina/file;
import ballerina/io;
import ballerina/log;

// Guards against a new sweep starting while a previous sweep is still working through a
// backlog of files. When true, the next due trigger is skipped rather than queued.
boolean sweepInProgress = false;

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

// Runs a single sweep of the inbox folder: lists every file present, processes each one in
// turn, and never lets a single bad file stop the rest of the batch from being processed.
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
        }
    }
}

// Processes a single file from the inbox: counts its data rows, logs a one-line summary, and
// moves it into the processed folder. Any failure while reading or moving the file is
// surfaced to the caller as an error so it can be logged and the file left where it is.
function processInboxFile(string sourceFilePath, string processedPath) returns error? {
    string[][] rows = check io:fileReadCsv(sourceFilePath);
    int dataRowCount = rows.length() > 0 ? rows.length() - 1 : 0;

    string fileName = check file:basename(sourceFilePath);
    string destinationFilePath = check file:joinPath(processedPath, fileName);
    check file:rename(sourceFilePath, destinationFilePath);

    log:printInfo(string `Processed file ${fileName}: ${dataRowCount} data row(s)`);
}
