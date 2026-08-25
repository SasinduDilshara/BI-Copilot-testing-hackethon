import ballerina/ftp;
import ballerina/log;

@ftp:ServiceConfig {
    path: ordersDropPath,
    fileNamePattern: "(.*).csv"
}
service on orderFileListener {

    remote function onFileCsv(Order[] contents, ftp:FileInfo fileInfo) returns error? {
        log:printInfo("New partner order file received", fileName = fileInfo.name, path = fileInfo.path);

        foreach Order 'order in contents {
            error? result = processOrder('order);
            if result is error {
                log:printError("Failed to process order", 'error = result, orderId = 'order.orderId,
                        fileName = fileInfo.name);
            }
        }
    }

    remote function onError(ftp:Error ftpError) returns error? {
        log:printError("Error while polling the SFTP drop directory", 'error = ftpError);
    }
}
