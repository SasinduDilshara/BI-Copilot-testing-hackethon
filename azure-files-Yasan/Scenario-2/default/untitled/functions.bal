import ballerina/log;

// Logs the name and text contents of a newly arrived order file.
function logIncomingOrderFile(string fileName, string textContent) {
    log:printInfo("New order file received", fileName = fileName, content = textContent);
}

// Logs an error that occurred while watching or reading from the file share.
function logOrderFileError(error err) {
    log:printError("Error while processing order file share", 'error = err);
}
