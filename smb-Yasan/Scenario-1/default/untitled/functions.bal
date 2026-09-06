import ballerina/lang.regexp;
import ballerina/log;
import ballerina/smb;

const string OUTGOING_DIR = "/outgoing";
const string PROCESSED_DIR = "/processed";
const string ARCHIVE_DIR = "/archive";
const string ERROR_DIR = "/error";

final string orderFileNameRegexPattern = "^orders-\\d{8}\\.csv$";
final regexp:RegExp orderFileNamePattern = check regexp:fromString(orderFileNameRegexPattern);

// Lists the outgoing directory and processes every file that matches the order file naming convention.
// Each file is isolated: a file that fails to read/bind or validate is moved to /error and logged,
// while every other file continues to be processed normally.
function processOutgoingOrderFiles() returns error? {
    smb:FileInfo[] files = check partnerShareClient->list(OUTGOING_DIR);
    foreach smb:FileInfo file in files {
        if file.isDirectory {
            continue;
        }
        string fileName = file.name;
        if !orderFileNamePattern.isFullMatch(fileName) {
            continue;
        }

        error? result = processOrderFile(fileName);
        if result is error {
            handleFileFailure(fileName, result);
        }
    }
}

// Reads, validates, summarizes, and archives a single order file.
// Returns an error (without having moved the file) when the file cannot be read/bound or contains an invalid line.
function processOrderFile(string fileName) returns error? {
    string sourcePath = string `${OUTGOING_DIR}/${fileName}`;
    OrderLine[]|error orderLines = partnerShareClient->getCsv(sourcePath);
    if orderLines is error {
        return error(string `Failed to read/bind CSV content: ${orderLines.message()}`, orderLines);
    }

    foreach int lineIndex in 0 ..< orderLines.length() {
        OrderLine orderLine = orderLines[lineIndex];
        if !isValidOrderLine(orderLine) {
            int physicalLine = lineIndex + 2;
            return error(string `Invalid order line at line ${physicalLine}: qty=${orderLine.qty}, unitPrice=${orderLine.unitPrice}`);
        }
    }

    OrderFileSummary summary = buildOrderFileSummary(orderLines);
    string summaryPath = string `${PROCESSED_DIR}/${fileName}.summary.json`;
    check partnerShareClient->putJson(summaryPath, summary.toJson(), smb:OVERWRITE);

    string archivePath = string `${ARCHIVE_DIR}/${fileName}`;
    check partnerShareClient->move(sourcePath, archivePath);

    log:printInfo(string `Processed file ${fileName}: ${summary.orderCount} orders, grand total ${summary.grandTotal}`);
}

// Logs the failure with the file name and moves the offending file from /outgoing to /error.
// A failure to move the file itself is logged but does not propagate, so the run continues.
function handleFileFailure(string fileName, error cause) {
    log:printError(string `Skipping file ${fileName}: ${cause.message()}`, cause);

    string sourcePath = string `${OUTGOING_DIR}/${fileName}`;
    string errorPath = string `${ERROR_DIR}/${fileName}`;
    error? moveResult = partnerShareClient->move(sourcePath, errorPath);
    if moveResult is error {
        log:printError(string `Failed to move ${fileName} to ${ERROR_DIR}`, moveResult);
    }
}

// Validates a single order line: qty must be greater than 0 and unitPrice must be at least 0.
function isValidOrderLine(OrderLine orderLine) returns boolean {
    return orderLine.qty > 0 && orderLine.unitPrice >= 0d;
}

// Builds the per-file summary: order count, per-sku quantity map, and grand total amount.
function buildOrderFileSummary(OrderLine[] orderLines) returns OrderFileSummary {
    map<int> quantityBySku = {};
    decimal grandTotal = 0d;
    foreach OrderLine orderLine in orderLines {
        string sku = orderLine.sku;
        int existingQty = quantityBySku.hasKey(sku) ? quantityBySku.get(sku) : 0;
        quantityBySku[sku] = existingQty + orderLine.qty;
        grandTotal += <decimal>orderLine.qty * orderLine.unitPrice;
    }
    return {
        orderCount: orderLines.length(),
        quantityBySku,
        grandTotal
    };
}
