import ballerina/ftp;
import ballerina/log;

public function main() returns error? {
    ftp:FileInfo[] outgoingFiles = check sftpClient->list(OUTGOING_DIR);

    foreach ftp:FileInfo fileInfo in outgoingFiles {
        if fileInfo.isFolder || !isOrderFile(fileInfo.name) {
            continue;
        }
        error? result = processOrderFile(fileInfo.name);
        if result is error {
            log:printError(string `Failed to process file ${fileInfo.name}`, 'error = result);
        }
    }
}

// Downloads, validates, summarizes, uploads the summary, and archives a single order file.
// Any file with a malformed or business-rule-invalid row is moved to /error instead of being
// left in /outgoing, so it is not repeatedly re-downloaded and re-processed on every run.
function processOrderFile(string fileName) returns error? {
    string sourcePath = string `${OUTGOING_DIR}/${fileName}`;

    OrderLine[]|ftp:Error csvBindResult = sftpClient->getCsv(sourcePath);
    if csvBindResult is ftp:Error {
        int malformedLine = check locateMalformedLine(sourcePath);
        log:printError(string `Malformed row in file ${fileName} at line ${malformedLine}`, 'error = csvBindResult);
        check moveToErrorDirectory(sourcePath, fileName);
        return;
    }

    OrderLine[] orderLines = csvBindResult;
    FileValidationResult validationResult = validateOrderFile(fileName, orderLines);
    if !validationResult.valid {
        log:printWarn(string `Moving file ${fileName} to ${ERROR_DIR} due to invalid line(s)`);
        check moveToErrorDirectory(sourcePath, fileName);
        return;
    }

    OrderFileSummary summary = buildOrderFileSummary(validationResult.lines);
    string summaryPath = string `${PROCESSED_DIR}/${fileName}.summary.json`;
    check sftpClient->putJson(summaryPath, summary, ftp:OVERWRITE);

    string archivePath = string `${ARCHIVE_DIR}/${fileName}`;
    check sftpClient->move(sourcePath, archivePath);

    log:printInfo(string `Processed file ${fileName}: ${summary.orderCount} order(s), grand total ${summary.grandTotal.toString()}`);
}

// Re-reads the file as raw rows to identify which line failed to bind into an OrderLine.
function locateMalformedLine(string sourcePath) returns int|error {
    string[][] rawRows = check sftpClient->getCsv(sourcePath);
    return findMalformedLine(rawRows);
}

// Moves a file from /outgoing to /error on the server.
function moveToErrorDirectory(string sourcePath, string fileName) returns error? {
    string errorPath = string `${ERROR_DIR}/${fileName}`;
    check sftpClient->move(sourcePath, errorPath);
}
