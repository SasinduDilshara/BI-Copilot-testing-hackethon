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
function processOrderFile(string fileName) returns error? {
    string sourcePath = string `${OUTGOING_DIR}/${fileName}`;

    OrderCsvRow[] csvRows = check sftpClient->getCsv(sourcePath);
    FileValidationResult validationResult = check validateOrderFile(fileName, csvRows);

    if !validationResult.valid {
        log:printWarn(string `Skipping file ${fileName} due to invalid line(s)`);
        return;
    }

    OrderFileSummary summary = buildOrderFileSummary(validationResult.lines);
    string summaryPath = string `${PROCESSED_DIR}/${fileName}.summary.json`;
    check sftpClient->putJson(summaryPath, summary, ftp:OVERWRITE);

    string archivePath = string `${ARCHIVE_DIR}/${fileName}`;
    check sftpClient->move(sourcePath, archivePath);

    log:printInfo(string `Processed file ${fileName}: ${summary.orderCount} order(s), grand total ${summary.grandTotal.toString()}`);
}
