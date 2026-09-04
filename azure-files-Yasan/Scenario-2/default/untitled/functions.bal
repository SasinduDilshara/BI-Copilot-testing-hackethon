import ballerina/log;

// Logs the name of a newly arrived order file along with its parsed orders.
function logParsedOrders(string fileName, Order[] orders) {
    foreach Order 'order in orders {
        log:printInfo("Parsed order from incoming file", fileName = fileName, 'order = 'order);
    }
}

// Logs an error that occurred while watching or reading from the file share.
function logOrderFileError(error err) {
    log:printError("Error while processing order file share", 'error = err);
}
