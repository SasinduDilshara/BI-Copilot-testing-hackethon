import ballerina/file;
import ballerina/log;

string incomingDirectory = check file:joinPath(baseDirectory, "incoming");
string organizedDirectory = check file:joinPath(baseDirectory, "organized");
string quarantineDirectory = check file:joinPath(baseDirectory, "quarantine");

boolean directoryTreeReady = check initializeDirectoryTree();

function initializeDirectoryTree() returns boolean|error {
    check ensureDirectoryExists(baseDirectory);
    check ensureDirectoryExists(incomingDirectory);
    check ensureDirectoryExists(organizedDirectory);
    check ensureDirectoryExists(quarantineDirectory);
    log:printInfo("Directory tree ready", baseDirectory = baseDirectory);
    return true;
}

listener file:Listener incomingListener = new ({
    path: incomingDirectory,
    recursive: false
});

service "incomingFolderWatcher" on incomingListener {

    remote function onCreate(file:FileEvent fileEvent) returns error? {
        string fileName = check file:basename(fileEvent.name);
        log:printInfo("File event received", name = fileName, operation = fileEvent.operation);
        organizeFile(fileEvent.name, fileName, organizedDirectory, quarantineDirectory);
    }

    remote function onModify(file:FileEvent fileEvent) returns error? {
        string fileName = check file:basename(fileEvent.name);
        log:printInfo("File event received", name = fileName, operation = fileEvent.operation);
    }

    remote function onDelete(file:FileEvent fileEvent) returns error? {
        string fileName = check file:basename(fileEvent.name);
        log:printInfo("File event received", name = fileName, operation = fileEvent.operation);
    }
}
