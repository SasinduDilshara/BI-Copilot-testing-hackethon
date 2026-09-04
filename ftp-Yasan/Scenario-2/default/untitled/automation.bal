import ballerina/ftp;
import ballerina/log;

@ftp:ServiceConfig {
    path: inboundPath,
    fileNamePattern: "^orders-\\d{8}\\.csv$"
}
service on orderIntakeListener {

    remote function onFileCsv(stream<OrderLine, error?> content, ftp:FileInfo fileInfo) returns error? {
        string fileName = fileInfo.name;

        OrderLine[] orderLines = [];
        // Row 1 is the header, so the first data row is physical line 2.
        int physicalLine = 2;

        while true {
            record {|OrderLine value;|}|error? next = content.next();

            if next is error {
                log:printError("malformed order line, moving file to error directory",
                        fileName = fileName, lineNumber = physicalLine, 'error = next);
                check content.close();
                check moveToError(fileName);
                return;
            }

            if next is () {
                break;
            }

            OrderLine orderLine = next.value;
            error? validationError = validateOrderLine(orderLine);
            if validationError is error {
                log:printError("invalid order line, moving file to error directory",
                        fileName = fileName, lineNumber = physicalLine, line = orderLine.toString(),
                        'error = validationError);
                check content.close();
                check moveToError(fileName);
                return;
            }

            orderLines.push(orderLine);
            physicalLine += 1;
        }

        check content.close();

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
