import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerina/lang.regexp;
import ballerina/time;
import ballerinax/azure.storage.files;

// Ensures the configured share exists, creating it if it does not.
function ensureShareExists() returns error? {
    boolean shareExists = check azureFilesAdminClient->hasShare(shareName);
    if !shareExists {
        check azureFilesAdminClient->createShare(shareName);
    }
}

// Builds the archive root directory path for today, e.g. /archive/2026-09-04.
function buildArchiveRootPath() returns string|error {
    time:Utc currentUtc = time:utcNow();
    time:Civil currentCivil = time:utcToCivil(currentUtc);
    string year = currentCivil.year.toString();
    string month = currentCivil.month < 10 ? string `0${currentCivil.month}` : currentCivil.month.toString();
    string day = currentCivil.day < 10 ? string `0${currentCivil.day}` : currentCivil.day.toString();
    return string `/archive/${year}-${month}-${day}`;
}

// Creates the given directory on the share along with every intermediate parent
// directory, since Azure Files does not create intermediate directories automatically.
function ensureDirectoryPath(string directoryPath) returns error? {
    string[] segments = re `/`.split(directoryPath);
    string currentPath = "";
    foreach string segment in segments {
        if segment.trim().length() == 0 {
            continue;
        }
        currentPath = string `${currentPath}/${segment}`;
        error? createResult = azureFilesClient->createDirectory(currentPath);
        if createResult is error {
            // Ignore the error only when the directory already exists; propagate otherwise.
            string createErrorMessage = createResult.message();
            if !createErrorMessage.toLowerAscii().includes("already exists") {
                return createResult;
            }
        }
    }
}

// Recursively collects the absolute local file paths under the given local directory.
function collectLocalFilePaths(string directoryPath) returns string[]|error {
    string[] filePaths = [];
    file:MetaData[] entries = check file:readDir(directoryPath);
    foreach file:MetaData entry in entries {
        string entryPath = entry.absPath;
        if entry.dir {
            string[] nestedFilePaths = check collectLocalFilePaths(entryPath);
            filePaths.push(...nestedFilePaths);
        } else {
            filePaths.push(entryPath);
        }
    }
    return filePaths;
}

// Recursively uploads every file under the local reports directory to the share, preserving
// the local subfolder structure beneath the given archive root path. Returns the manifest
// of uploaded files.
function archiveReportsDirectory(string localDirectoryPath, string archiveRootPath) returns UploadManifest|error {
    string[] localFilePaths = check collectLocalFilePaths(localDirectoryPath);

    UploadedFileEntry[] uploadedFiles = [];
    int totalBytes = 0;

    foreach string localFilePath in localFilePaths {
        string relativePath = check file:relativePath(localDirectoryPath, localFilePath);
        string normalizedRelativePath = re `\\`.replaceAll(relativePath, "/");
        string destinationPath = string `${archiveRootPath}/${normalizedRelativePath}`;

        int lastSlashIndex = 0;
        int? foundIndex = destinationPath.lastIndexOf("/");
        if foundIndex is int {
            lastSlashIndex = foundIndex;
        }
        string destinationDirectory = destinationPath.substring(0, lastSlashIndex);
        check ensureDirectoryPath(destinationDirectory);

        check azureFilesClient->uploadFromFile(localFilePath, destinationPath);

        files:FileProperties uploadedFileProperties = check azureFilesClient->getFileProperties(destinationPath);
        int fileSizeInBytes = uploadedFileProperties.contentLength;

        uploadedFiles.push({sharePath: destinationPath, sizeInBytes: fileSizeInBytes});
        totalBytes += fileSizeInBytes;
    }

    return {
        uploadedFiles,
        totalFiles: uploadedFiles.length(),
        totalBytes
    };
}

// Prints the upload manifest: each uploaded file's destination share path and size in bytes,
// followed by the total number of files and total bytes uploaded.
function printManifest(UploadManifest manifest) {
    foreach UploadedFileEntry uploadedFile in manifest.uploadedFiles {
        io:println(string `${uploadedFile.sharePath} - ${uploadedFile.sizeInBytes} bytes`);
    }
    io:println(string `Total files: ${manifest.totalFiles}, Total bytes: ${manifest.totalBytes}`);
}

// Parses a directory name of the form yyyy-MM-dd into a time:Civil date at midnight UTC.
// Returns an error if the name does not match that format.
function parseArchiveDate(string archiveDateName) returns time:Civil|error {
    string:RegExp datePattern = re `^([0-9]{4})-([0-9]{2})-([0-9]{2});
    regexp:Groups? groups = datePattern.findGroups(archiveDateName);
    if groups is () {
        return error(string `'${archiveDateName}' is not a yyyy-MM-dd date`);
    }
    regexp:Span? yearSpan = groups[1];
    regexp:Span? monthSpan = groups[2];
    regexp:Span? daySpan = groups[3];
    if yearSpan is () || monthSpan is () || daySpan is () {
        return error(string `'${archiveDateName}' is not a yyyy-MM-dd date`);
    }
    int year = check int:fromString(yearSpan.substring());
    int month = check int:fromString(monthSpan.substring());
    int day = check int:fromString(daySpan.substring());
    return {year, month, day, hour: 0, minute: 0, second: 0};
}

// PLACEHOLDER_MARKER_TO_REMOVE_DUPLICATE_TAIL
function placeholderToRemoveDuplicateTail() returns int|error {
    string:RegExp datePattern = re `^([0-9]{4})-([0-9]{2})-([0-9]{2})import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerina/lang.regexp;
import ballerina/time;
import ballerinax/azure.storage.files;

// Ensures the configured share exists, creating it if it does not.
function ensureShareExists() returns error? {
    boolean shareExists = check azureFilesAdminClient->hasShare(shareName);
    if !shareExists {
        check azureFilesAdminClient->createShare(shareName);
    }
}

// Builds the archive root directory path for today, e.g. /archive/2026-09-04.
function buildArchiveRootPath() returns string|error {
    time:Utc currentUtc = time:utcNow();
    time:Civil currentCivil = time:utcToCivil(currentUtc);
    string year = currentCivil.year.toString();
    string month = currentCivil.month < 10 ? string `0${currentCivil.month}` : currentCivil.month.toString();
    string day = currentCivil.day < 10 ? string `0${currentCivil.day}` : currentCivil.day.toString();
    return string `/archive/${year}-${month}-${day}`;
}

// Creates the given directory on the share along with every intermediate parent
// directory, since Azure Files does not create intermediate directories automatically.
function ensureDirectoryPath(string directoryPath) returns error? {
    string[] segments = re `/`.split(directoryPath);
    string currentPath = "";
    foreach string segment in segments {
        if segment.trim().length() == 0 {
            continue;
        }
        currentPath = string `${currentPath}/${segment}`;
        error? createResult = azureFilesClient->createDirectory(currentPath);
        if createResult is error {
            // Ignore the error only when the directory already exists; propagate otherwise.
            string createErrorMessage = createResult.message();
            if !createErrorMessage.toLowerAscii().includes("already exists") {
                return createResult;
            }
        }
    }
}

// Recursively collects the absolute local file paths under the given local directory.
function collectLocalFilePaths(string directoryPath) returns string[]|error {
    string[] filePaths = [];
    file:MetaData[] entries = check file:readDir(directoryPath);
    foreach file:MetaData entry in entries {
        string entryPath = entry.absPath;
        if entry.dir {
            string[] nestedFilePaths = check collectLocalFilePaths(entryPath);
            filePaths.push(...nestedFilePaths);
        } else {
            filePaths.push(entryPath);
        }
    }
    return filePaths;
}

// Recursively uploads every file under the local reports directory to the share, preserving
// the local subfolder structure beneath the given archive root path. Returns the manifest
// of uploaded files.
function archiveReportsDirectory(string localDirectoryPath, string archiveRootPath) returns UploadManifest|error {
    string[] localFilePaths = check collectLocalFilePaths(localDirectoryPath);

    UploadedFileEntry[] uploadedFiles = [];
    int totalBytes = 0;

    foreach string localFilePath in localFilePaths {
        string relativePath = check file:relativePath(localDirectoryPath, localFilePath);
        string normalizedRelativePath = re `\\`.replaceAll(relativePath, "/");
        string destinationPath = string `${archiveRootPath}/${normalizedRelativePath}`;

        int lastSlashIndex = 0;
        int? foundIndex = destinationPath.lastIndexOf("/");
        if foundIndex is int {
            lastSlashIndex = foundIndex;
        }
        string destinationDirectory = destinationPath.substring(0, lastSlashIndex);
        check ensureDirectoryPath(destinationDirectory);

        check azureFilesClient->uploadFromFile(localFilePath, destinationPath);

        files:FileProperties uploadedFileProperties = check azureFilesClient->getFileProperties(destinationPath);
        int fileSizeInBytes = uploadedFileProperties.contentLength;

        uploadedFiles.push({sharePath: destinationPath, sizeInBytes: fileSizeInBytes});
        totalBytes += fileSizeInBytes;
    }

    return {
        uploadedFiles,
        totalFiles: uploadedFiles.length(),
        totalBytes
    };
}

// Prints the upload manifest: each uploaded file's destination share path and size in bytes,
// followed by the total number of files and total bytes uploaded.
function printManifest(UploadManifest manifest) {
    foreach UploadedFileEntry uploadedFile in manifest.uploadedFiles {
        io:println(string `${uploadedFile.sharePath} - ${uploadedFile.sizeInBytes} bytes`);
    }
    io:println(string `Total files: ${manifest.totalFiles}, Total bytes: ${manifest.totalBytes}`);
}

// Parses a directory name of the form yyyy-MM-dd into a time:Civil date at midnight UTC.
// Returns an error if the name does not match that format.
function parseArchiveDate(string archiveDateName) returns time:Civil|error {
    string:RegExp datePattern = re `^([0-9]{4})-([0-9]{2})-([0-9]{2})import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerina/lang.regexp;
import ballerina/time;
import ballerinax/azure.storage.files;

// Ensures the configured share exists, creating it if it does not.
function ensureShareExists() returns error? {
    boolean shareExists = check azureFilesAdminClient->hasShare(shareName);
    if !shareExists {
        check azureFilesAdminClient->createShare(shareName);
    }
}

// Builds the archive root directory path for today, e.g. /archive/2026-09-04.
function buildArchiveRootPath() returns string|error {
    time:Utc currentUtc = time:utcNow();
    time:Civil currentCivil = time:utcToCivil(currentUtc);
    string year = currentCivil.year.toString();
    string month = currentCivil.month < 10 ? string `0${currentCivil.month}` : currentCivil.month.toString();
    string day = currentCivil.day < 10 ? string `0${currentCivil.day}` : currentCivil.day.toString();
    return string `/archive/${year}-${month}-${day}`;
}

// Creates the given directory on the share along with every intermediate parent
// directory, since Azure Files does not create intermediate directories automatically.
function ensureDirectoryPath(string directoryPath) returns error? {
    string[] segments = re `/`.split(directoryPath);
    string currentPath = "";
    foreach string segment in segments {
        if segment.trim().length() == 0 {
            continue;
        }
        currentPath = string `${currentPath}/${segment}`;
        error? createResult = azureFilesClient->createDirectory(currentPath);
        if createResult is error {
            // Ignore the error only when the directory already exists; propagate otherwise.
            string createErrorMessage = createResult.message();
            if !createErrorMessage.toLowerAscii().includes("already exists") {
                return createResult;
            }
        }
    }
}

// Recursively collects the absolute local file paths under the given local directory.
function collectLocalFilePaths(string directoryPath) returns string[]|error {
    string[] filePaths = [];
    file:MetaData[] entries = check file:readDir(directoryPath);
    foreach file:MetaData entry in entries {
        string entryPath = entry.absPath;
        if entry.dir {
            string[] nestedFilePaths = check collectLocalFilePaths(entryPath);
            filePaths.push(...nestedFilePaths);
        } else {
            filePaths.push(entryPath);
        }
    }
    return filePaths;
}

// Recursively uploads every file under the local reports directory to the share, preserving
// the local subfolder structure beneath the given archive root path. Returns the manifest
// of uploaded files.
function archiveReportsDirectory(string localDirectoryPath, string archiveRootPath) returns UploadManifest|error {
    string[] localFilePaths = check collectLocalFilePaths(localDirectoryPath);

    UploadedFileEntry[] uploadedFiles = [];
    int totalBytes = 0;

    foreach string localFilePath in localFilePaths {
        string relativePath = check file:relativePath(localDirectoryPath, localFilePath);
        string normalizedRelativePath = re `\\`.replaceAll(relativePath, "/");
        string destinationPath = string `${archiveRootPath}/${normalizedRelativePath}`;

        int lastSlashIndex = 0;
        int? foundIndex = destinationPath.lastIndexOf("/");
        if foundIndex is int {
            lastSlashIndex = foundIndex;
        }
        string destinationDirectory = destinationPath.substring(0, lastSlashIndex);
        check ensureDirectoryPath(destinationDirectory);

        check azureFilesClient->uploadFromFile(localFilePath, destinationPath);

        files:FileProperties uploadedFileProperties = check azureFilesClient->getFileProperties(destinationPath);
        int fileSizeInBytes = uploadedFileProperties.contentLength;

        uploadedFiles.push({sharePath: destinationPath, sizeInBytes: fileSizeInBytes});
        totalBytes += fileSizeInBytes;
    }

    return {
        uploadedFiles,
        totalFiles: uploadedFiles.length(),
        totalBytes
    };
}

// Prints the upload manifest: each uploaded file's destination share path and size in bytes,
// followed by the total number of files and total bytes uploaded.
function printManifest(UploadManifest manifest) {
    foreach UploadedFileEntry uploadedFile in manifest.uploadedFiles {
        io:println(string `${uploadedFile.sharePath} - ${uploadedFile.sizeInBytes} bytes`);
    }
    io:println(string `Total files: ${manifest.totalFiles}, Total bytes: ${manifest.totalBytes}`);
}

// Parses a directory name of the form yyyy-MM-dd into a time:Civil date at midnight UTC.
// Returns an error if the name does not match that format.
function parseArchiveDate(string archiveDateName) returns time:Civil|error {
    string:RegExp datePattern = re `^([0-9]{4})-([0-9]{2})-([0-9]{2})import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerina/lang.regexp;
import ballerina/time;
import ballerinax/azure.storage.files;

// Ensures the configured share exists, creating it if it does not.
function ensureShareExists() returns error? {
    boolean shareExists = check azureFilesAdminClient->hasShare(shareName);
    if !shareExists {
        check azureFilesAdminClient->createShare(shareName);
    }
}

// Builds the archive root directory path for today, e.g. /archive/2026-09-04.
function buildArchiveRootPath() returns string|error {
    time:Utc currentUtc = time:utcNow();
    time:Civil currentCivil = time:utcToCivil(currentUtc);
    string year = currentCivil.year.toString();
    string month = currentCivil.month < 10 ? string `0${currentCivil.month}` : currentCivil.month.toString();
    string day = currentCivil.day < 10 ? string `0${currentCivil.day}` : currentCivil.day.toString();
    return string `/archive/${year}-${month}-${day}`;
}

// Creates the given directory on the share along with every intermediate parent
// directory, since Azure Files does not create intermediate directories automatically.
function ensureDirectoryPath(string directoryPath) returns error? {
    string[] segments = re `/`.split(directoryPath);
    string currentPath = "";
    foreach string segment in segments {
        if segment.trim().length() == 0 {
            continue;
        }
        currentPath = string `${currentPath}/${segment}`;
        error? createResult = azureFilesClient->createDirectory(currentPath);
        if createResult is error {
            // Ignore the error only when the directory already exists; propagate otherwise.
            string createErrorMessage = createResult.message();
            if !createErrorMessage.toLowerAscii().includes("already exists") {
                return createResult;
            }
        }
    }
}

// Recursively collects the absolute local file paths under the given local directory.
function collectLocalFilePaths(string directoryPath) returns string[]|error {
    string[] filePaths = [];
    file:MetaData[] entries = check file:readDir(directoryPath);
    foreach file:MetaData entry in entries {
        string entryPath = entry.absPath;
        if entry.dir {
            string[] nestedFilePaths = check collectLocalFilePaths(entryPath);
            filePaths.push(...nestedFilePaths);
        } else {
            filePaths.push(entryPath);
        }
    }
    return filePaths;
}

// Recursively uploads every file under the local reports directory to the share, preserving
// the local subfolder structure beneath the given archive root path. Returns the manifest
// of uploaded files.
function archiveReportsDirectory(string localDirectoryPath, string archiveRootPath) returns UploadManifest|error {
    string[] localFilePaths = check collectLocalFilePaths(localDirectoryPath);

    UploadedFileEntry[] uploadedFiles = [];
    int totalBytes = 0;

    foreach string localFilePath in localFilePaths {
        string relativePath = check file:relativePath(localDirectoryPath, localFilePath);
        string normalizedRelativePath = re `\\`.replaceAll(relativePath, "/");
        string destinationPath = string `${archiveRootPath}/${normalizedRelativePath}`;

        int lastSlashIndex = 0;
        int? foundIndex = destinationPath.lastIndexOf("/");
        if foundIndex is int {
            lastSlashIndex = foundIndex;
        }
        string destinationDirectory = destinationPath.substring(0, lastSlashIndex);
        check ensureDirectoryPath(destinationDirectory);

        check azureFilesClient->uploadFromFile(localFilePath, destinationPath);

        files:FileProperties uploadedFileProperties = check azureFilesClient->getFileProperties(destinationPath);
        int fileSizeInBytes = uploadedFileProperties.contentLength;

        uploadedFiles.push({sharePath: destinationPath, sizeInBytes: fileSizeInBytes});
        totalBytes += fileSizeInBytes;
    }

    return {
        uploadedFiles,
        totalFiles: uploadedFiles.length(),
        totalBytes
    };
}

// Prints the upload manifest: each uploaded file's destination share path and size in bytes,
// followed by the total number of files and total bytes uploaded.
function printManifest(UploadManifest manifest) {
    foreach UploadedFileEntry uploadedFile in manifest.uploadedFiles {
        io:println(string `${uploadedFile.sharePath} - ${uploadedFile.sizeInBytes} bytes`);
    }
    io:println(string `Total files: ${manifest.totalFiles}, Total bytes: ${manifest.totalBytes}`);
}

// Parses a directory name of the form yyyy-MM-dd into a time:Civil date at midnight UTC.
// Returns an error if the name does not match that format.
function parseArchiveDate(string archiveDateName) returns time:Civil|error {
    string:RegExp datePattern = re `^([0-9]{4})-([0-9]{2})-([0-9]{2});
    regexp:Groups? groups = datePattern.findGroups(archiveDateName);
    if groups is () {
        return error(string `'${archiveDateName}' is not a yyyy-MM-dd date`);
    }
    regexp:Span? yearSpan = groups[1];
    regexp:Span? monthSpan = groups[2];
    regexp:Span? daySpan = groups[3];
    if yearSpan is () || monthSpan is () || daySpan is () {
        return error(string `'${archiveDateName}' is not a yyyy-MM-dd date`);
    }
    int year = check int:fromString(yearSpan.substring());
    int month = check int:fromString(monthSpan.substring());
    int day = check int:fromString(daySpan.substring());
    return {year, month, day, hour: 0, minute: 0, second: 0};
}

// PLACEHOLDER_MARKER_TO_REMOVE_DUPLICATE_TAIL
function placeholderToRemoveDuplicateTail() returns int|error {
    string:RegExp datePattern = re `^([0-9]{4})-([0-9]{2})-([0-9]{2});
    regexp:Groups? groups = datePattern.findGroups(archiveDateName);
    if groups is () {
        return error(string `'${archiveDateName}' is not a yyyy-MM-dd date`);
    }
    regexp:Span? yearSpan = groups[1];
    regexp:Span? monthSpan = groups[2];
    regexp:Span? daySpan = groups[3];
    if yearSpan is () || monthSpan is () || daySpan is () {
        return error(string `'${archiveDateName}' is not a yyyy-MM-dd date`);
    }
    int year = check int:fromString(yearSpan.substring());
    int month = check int:fromString(monthSpan.substring());
    int day = check int:fromString(daySpan.substring());
    return {year, month, day, hour: 0, minute: 0, second: 0};
}

// Recursively deletes every file and subdirectory under the given directory, then deletes
// the directory itself. Returns the number of files that were deleted.
function deleteDirectoryRecursively(string directoryPath) returns int|error {
    stream<files:Entry, files:Error?> entryStream = check azureFilesClient->list(directoryPath, {recursive: true});

    string[] filePaths = [];
    string[] subDirectoryPaths = [];
    error? streamError = entryStream.forEach(function(files:Entry entry) {
        if entry.isDirectory {
            subDirectoryPaths.push(entry.path);
        } else {
            filePaths.push(entry.path);
        }
    });
    if streamError is error {
        return streamError;
    }

    foreach string filePath in filePaths {
        check azureFilesClient->deleteFile(filePath);
    }

    // Delete the deepest subdirectories first so every directory is empty when removed.
    string[] sortedSubDirectoryPaths = subDirectoryPaths.sort(array:DESCENDING, key = function(string path) returns int {
        return path.length();
    });
    foreach string subDirectoryPath in sortedSubDirectoryPaths {
        check azureFilesClient->deleteDirectory(subDirectoryPath);
    }

    check azureFilesClient->deleteDirectory(directoryPath);

    return filePaths.length();
}

// Deletes any /archive/<date> directory (and everything under it) whose date is older than
// the configured retention window, discovered via the share listing. Leaves today's archive
// and anything within the retention window untouched. Returns a report of what was pruned.
function applyArchiveRetentionPolicy(int retentionWindowDays) returns RetentionReport|error {
    time:Utc nowUtc = time:utcNow();
    time:Utc cutoffUtc = time:utcAddSeconds(nowUtc, -retentionWindowDays * 24 * 60 * 60);

    stream<files:Entry, files:Error?> archiveEntryStream = check azureFilesClient->list("/archive");

    PrunedArchiveEntry[] prunedArchives = [];
    error? streamError = archiveEntryStream.forEach(function(files:Entry entry) {
        if !entry.isDirectory {
            return;
        }
        string archiveDateName = entry.name;
        time:Civil|error archiveDateCivil = parseArchiveDate(archiveDateName);
        if archiveDateCivil is error {
            // Not a dated archive directory; leave it untouched.
            return;
        }
        time:Utc|error archiveDateUtc = time:utcFromCivil(archiveDateCivil);
        if archiveDateUtc is error {
            return;
        }
        if archiveDateUtc >= cutoffUtc {
            // Within the retention window (or today); leave it untouched.
            return;
        }
        int|error deletedFileCount = deleteDirectoryRecursively(entry.path);
        if deletedFileCount is error {
            return;
        }
        prunedArchives.push({archiveDate: archiveDateName, fileCount: deletedFileCount});
    });
    if streamError is error {
        return streamError;
    }

    return {prunedArchives};
}

// Prints the retention report: each pruned archive date and how many files it contained.
function printRetentionReport(RetentionReport report) {
    if report.prunedArchives.length() == 0 {
        io:println("Retention: no archive dates were older than the retention window.");
        return;
    }
    foreach PrunedArchiveEntry prunedArchive in report.prunedArchives {
        io:println(string `Pruned archive ${prunedArchive.archiveDate} - ${prunedArchive.fileCount} files`);
    }
}

// Given a report's share path, returns a read-only download link for that single file that
// expires 24 hours from now, so an external auditor can fetch it without any account credentials.
function generateAuditorDownloadLink(string reportSharePath) returns string|error {
    time:Utc expiryTime = time:utcAddSeconds(time:utcNow(), 24 * 60 * 60);
    string sasToken = check azureFilesClient.generateSas(reportSharePath, {
        expiryTime,
        permissions: {read: true}
    });

    string fileUrl = string `https://${accountName}.file.core.windows.net/${shareName}${reportSharePath}`;
    return string `${fileUrl}?${sasToken}`;
}
