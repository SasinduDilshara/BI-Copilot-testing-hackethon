import ballerina/file;
import ballerina/io;
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
