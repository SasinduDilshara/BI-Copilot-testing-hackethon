import ballerinax/azure.storage.files;

// Listener that polls the configured Azure file share and dispatches each
// newly detected file to this service's handlers.
listener files:Listener orderFileListener = new (shareName, {
    auth: {
        accountName,
        accountKey
    }
});

// Watches the share root for new order files. Text-based files (e.g. .txt)
// are routed to onFileText; anything else falls back to onFile.
service files:Service / on orderFileListener {

    # Handles newly arrived text files by logging the file name and its
    # text contents.
    remote function onFileText(string content, files:FileInfo fileInfo) returns error? {
        logIncomingOrderFile(fileInfo.name, content);
    }

    # Fallback handler for files that are not matched as text content.
    # Logs the file name and its raw content decoded as text.
    remote function onFile(byte[] content, files:FileInfo fileInfo) returns error? {
        string textContent = check string:fromBytes(content);
        logIncomingOrderFile(fileInfo.name, textContent);
    }

    # Logs any failure that occurs while polling or downloading a file.
    remote function onError(files:Error err) returns error? {
        logOrderFileError(err);
    }
}
