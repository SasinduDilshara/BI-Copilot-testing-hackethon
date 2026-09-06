import ballerina/lang.regexp;
import ballerina/log;
import ballerina/smb;

const string OUTGOING_DIR = "/outgoing";
const string PROCESSED_DIR = "/processed";
const string ARCHIVE_DIR = "/archive";

final regexp:RegExp orderFileNamePattern = re `^orders-\d{8}\.csv$`;

// Lists the outgoing directory and processes every file that matches the order file naming convention.
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
        check processOrderFile(fileName);
    }
}

// Reads, validates, summarizes, and archives a single order file. Invalid files are skipped and logged.
function processOrderFile(string fileName) returns error? {
    string sourcePath = string `${OUTGOING_DIR}/${fileName}`;
    OrderLine[] orderLines = check partnerShareClient->getCsv(sourcePath);

    boolean allValid = true;
    foreach int lineIndex in 0 ..< orderLines.length() {
        OrderLine orderLine = orderLines[lineIndex];
        if !isValidOrderLine(orderLine) {
            allValid = false;
            log:printError(string `Invalid order line in file ${fileName} at line ${lineIndex + 2}: qty=${orderLine.qty}, unitPrice=${orderLine.unitPrice}`);
        }
    }

    if !allValid {
        log:printWarn(string `Skipping file ${fileName} due to validation failures`);
        return;
    }

    OrderFileSummary summary = buildOrderFileSummary(orderLines);
    string summaryPath = string `${PROCESSED_DIR}/${fileName}.summary.json`;
    check partnerShareClient->putJson(summaryPath, summary.toJson(), smb:OVERWRITE);

    string archivePath = string `${ARCHIVE_DIR}/${fileName}`;
    check partnerShareClient->move(sourcePath, archivePath);

    log:printInfo(string `Processed file ${fileName}: ${summary.orderCount} orders, grand total ${summary.grandTotal}`);
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
