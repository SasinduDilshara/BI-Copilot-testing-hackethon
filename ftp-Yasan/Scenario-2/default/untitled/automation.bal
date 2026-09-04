import ballerina/ftp;
import ballerina/log;

@ftp:ServiceConfig {
    path: inboundPath,
    fileNamePattern: "^orders-\\d{8}\\.csv$"
}
service on orderIntakeListener {

    remote function onFileCsv(string[][] content, ftp:FileInfo fileInfo) returns error? {
        string fileName = fileInfo.name;

        if content.length() == 0 {
            log:printError("orders file has no rows, moving to error directory", fileName = fileName);
            check moveToError(fileName);
            return;
        }

        string[] headerRow = content[0];
        string[][] dataRows = content.slice(1);

        OrderLine[] orderLines = [];
        foreach int rowIndex in 0 ..< dataRows.length() {
            string[] dataRow = dataRows[rowIndex];
            OrderLine|error orderLine = bindOrderLine(headerRow, dataRow);
            if orderLine is error {
                log:printError("malformed order line, moving file to error directory",
                        fileName = fileName, lineNumber = rowIndex + 2, line = dataRow.toString(), 'error = orderLine);
                check moveToError(fileName);
                return;
            }

            error? validationError = validateOrderLine(orderLine);
            if validationError is error {
                log:printError("invalid order line, moving file to error directory",
                        fileName = fileName, lineNumber = rowIndex + 2, line = dataRow.toString(), 'error = validationError);
                check moveToError(fileName);
                return;
            }

            orderLines.push(orderLine);
        }

        OrderSummary summary = computeOrderSummary(fileName, orderLines);

        string summaryPath = string `${processedPath}/${fileName}.summary.json`;
        check orderIntakeClient->putJson(summaryPath, summary);

        string archiveDestination = string `${archivePath}/${fileName}`;
        string inboundSourcePath = string `${inboundPath}/${fileName}`;
        check orderIntakeClient->rename(inboundSourcePath, archiveDestination);

        log:printInfo("processed orders file successfully", fileName = fileName, orderCount = summary.orderCount,
                grandTotal = summary.grandTotal);
    }

    remote function onError(ftp:Error err) returns error? {
        log:printError("error while polling or processing orders file", 'error = err);
    }
}

# Moves the given orders file from the inbound directory to the error directory.
#
# + fileName - The name of the file to move
# + return - An error if the move operation fails
function moveToError(string fileName) returns error? {
    string sourcePath = string `${inboundPath}/${fileName}`;
    string destinationPath = string `${errorPath}/${fileName}`;
    check orderIntakeClient->rename(sourcePath, destinationPath);
}
