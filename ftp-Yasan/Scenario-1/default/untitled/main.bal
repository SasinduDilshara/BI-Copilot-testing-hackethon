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

// Streams, validates, summarizes, uploads the summary, and archives a single order file.
// Rows are consumed one at a time from the module's own CSV stream, keeping only the running
// aggregate (order count, per-sku quantity map, grand total) in memory rather than a full list.
// Any file with a malformed or business-rule-invalid row is moved to /error instead of being
// left in /outgoing, so it is not repeatedly re-downloaded and re-processed on every run.
function processOrderFile(string fileName) returns error? {
    string sourcePath = string `${OUTGOING_DIR}/${fileName}`;

    stream<OrderLine, error?> orderLineStream = check sftpClient->getCsvAsStream(sourcePath, OrderLine);
    OrderFileAggregate aggregate = {};
    int rowsConsumed = 0;
    boolean fileValid = true;

    while true {
        record {|OrderLine value;|}|error? nextRow = orderLineStream.next();

        if nextRow is error {
            int malformedLine = rowsConsumed + 2;
            log:printError(string `Malformed row in file ${fileName} at line ${malformedLine}`, 'error = nextRow);
            fileValid = false;
            break;
        }

        if nextRow is () {
            break;
        }

        rowsConsumed += 1;
        OrderLine orderLine = nextRow.value;
        if !isValidOrderLine(orderLine) {
            int invalidLine = rowsConsumed + 1;
            log:printError(string `Invalid order line in file ${fileName} at line ${invalidLine}: ${orderLine.toString()}`);
            fileValid = false;
            break;
        }

        accumulateOrderLine(aggregate, orderLine);
    }
    check orderLineStream.close();

    if !fileValid {
        log:printWarn(string `Moving file ${fileName} to ${ERROR_DIR} due to a malformed or invalid line`);
        check moveToErrorDirectory(sourcePath, fileName);
        return;
    }

    OrderFileSummary summary = toOrderFileSummary(aggregate);
    string summaryPath = string `${PROCESSED_DIR}/${fileName}.summary.json`;
    check sftpClient->putJson(summaryPath, summary, ftp:OVERWRITE);

    string archivePath = string `${ARCHIVE_DIR}/${fileName}`;
    check sftpClient->move(sourcePath, archivePath);

    log:printInfo(string `Processed file ${fileName}: ${summary.orderCount} order(s), grand total ${summary.grandTotal.toString()}`);
}

// Moves a file from /outgoing to /error on the server.
function moveToErrorDirectory(string sourcePath, string fileName) returns error? {
    string errorPath = string `${ERROR_DIR}/${fileName}`;
    check sftpClient->move(sourcePath, errorPath);
}
