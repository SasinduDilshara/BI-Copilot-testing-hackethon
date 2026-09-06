import ballerina/file;
import ballerina/lang.regexp;
import ballerina/log;

# Derives the uppercase extension (without the dot) from a file name.
# Returns "NO_EXTENSION" when the file name has no extension.
#
# + fileName - The base name of the file
# + return - The uppercase extension without the dot, or "NO_EXTENSION"
function getExtensionFolder(string fileName) returns string {
    string:RegExp dotPattern = re `\.`;
    regexp:Span[] dotSpans = dotPattern.findAll(fileName);
    if dotSpans.length() == 0 {
        return "NO_EXTENSION";
    }
    regexp:Span lastDotSpan = dotSpans[dotSpans.length() - 1];
    int lastDotIndex = lastDotSpan.startIndex;
    if lastDotIndex == 0 || lastDotIndex == fileName.length() - 1 {
        return "NO_EXTENSION";
    }
    string extension = fileName.substring(lastDotIndex + 1);
    return extension.toUpperAscii();
}

# Ensures that the given directory exists, creating it (and any missing parents) if required.
#
# + dirPath - The directory path to ensure
# + return - A `file:Error` if the directory could not be created
function ensureDirectoryExists(string dirPath) returns file:Error? {
    file:Error? result = file:createDir(dirPath, file:RECURSIVE);
    if result is file:Error {
        string errorMessage = result.message();
        if errorMessage.includes("File already exists") {
            return ();
        }
        return result;
    }
    return ();
}

# Moves the file at sourcePath into the organized directory, grouped by its uppercase extension.
# If the move fails for any reason, the file is instead moved into the quarantine directory
# and the reason is logged.
#
# + sourcePath - The absolute path of the file to move
# + fileName - The base name of the file
# + organizedDirectory - The root organized directory path
# + quarantineDirectory - The quarantine directory path
function organizeFile(string sourcePath, string fileName, string organizedDirectory, string quarantineDirectory) {
    string extensionFolder = getExtensionFolder(fileName);
    string|file:Error targetDir = file:joinPath(organizedDirectory, extensionFolder);
    if targetDir is file:Error {
        log:printError("Failed to build target directory path, quarantining file", targetDir, name = fileName);
        quarantineFile(sourcePath, fileName, quarantineDirectory);
        return;
    }

    file:Error? dirResult = ensureDirectoryExists(targetDir);
    if dirResult is file:Error {
        log:printError("Failed to create organized subdirectory, quarantining file", dirResult, name = fileName);
        quarantineFile(sourcePath, fileName, quarantineDirectory);
        return;
    }

    string|file:Error targetPath = file:joinPath(targetDir, fileName);
    if targetPath is file:Error {
        log:printError("Failed to build target file path, quarantining file", targetPath, name = fileName);
        quarantineFile(sourcePath, fileName, quarantineDirectory);
        return;
    }

    file:Error? moveResult = file:rename(sourcePath, targetPath);
    if moveResult is file:Error {
        log:printError("Failed to move file into organized directory, quarantining file", moveResult, name = fileName);
        quarantineFile(sourcePath, fileName, quarantineDirectory);
        return;
    }

    log:printInfo("Moved file into organized directory", name = fileName, targetPath = targetPath);
}

# Moves the file at sourcePath into the quarantine directory and logs the outcome.
#
# + sourcePath - The absolute path of the file to move
# + fileName - The base name of the file
# + quarantineDirectory - The quarantine directory path
function quarantineFile(string sourcePath, string fileName, string quarantineDirectory) {
    string|file:Error targetPath = file:joinPath(quarantineDirectory, fileName);
    if targetPath is file:Error {
        log:printError("Failed to build quarantine file path", targetPath, name = fileName);
        return;
    }

    file:Error? moveResult = file:rename(sourcePath, targetPath);
    if moveResult is file:Error {
        log:printError("Failed to move file into quarantine directory", moveResult, name = fileName);
        return;
    }

    log:printInfo("Moved file into quarantine directory", name = fileName, targetPath = targetPath);
}
