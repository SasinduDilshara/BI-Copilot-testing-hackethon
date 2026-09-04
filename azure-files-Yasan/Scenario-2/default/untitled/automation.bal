import ballerinax/azure.storage.files;

// Listener that polls the configured Azure file share and dispatches each
// newly detected file to this service's handlers.
listener files:Listener orderFileListener = new (shareName, {
    auth: {
        accountName,
        accountKey
    }
});

// Watches the share root for new order files. CSV files are parsed into
// Order records; once a file is processed successfully it is moved into
// the 'done' folder so it is not picked up again.
service files:Service / on orderFileListener {

    # Handles newly arrived order CSV files by binding each row to an
    # Order record and logging the parsed orders. On success, the module
    # moves the file into the 'done' folder via afterProcess.
    @files:FunctionConfig {
        afterProcess: {
            moveTo: "/done"
        }
    }
    remote function onFileCsv(Order[] content, files:FileInfo fileInfo) returns error? {
        logParsedOrders(fileInfo.name, content);
    }

    # Logs any failure that occurs while polling, downloading, or binding
    # a file's content.
    remote function onError(files:Error err) returns error? {
        logOrderFileError(err);
    }
}
