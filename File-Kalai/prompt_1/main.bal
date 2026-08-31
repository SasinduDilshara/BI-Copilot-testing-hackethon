import ballerina/file;
import ballerina/http;
import ballerina/time;

service /documents on new http:Listener(9093) {

    resource function post process(ProcessRequest processRequest) returns ProcessResponse|FileNotFound|http:InternalServerError {
        string sourceFilePath = processRequest.sourceFilePath;

        boolean|file:Error existsResult = file:test(sourceFilePath, file:EXISTS);
        boolean|file:Error isDirResult = file:test(sourceFilePath, file:IS_DIR);

        if existsResult is file:Error {
            return <http:InternalServerError>{
                body: {message: existsResult.message(), path: sourceFilePath}
            };
        }
        if isDirResult is file:Error {
            return <http:InternalServerError>{
                body: {message: isDirResult.message(), path: sourceFilePath}
            };
        }

        boolean fileExists = existsResult;
        boolean isDirectory = isDirResult;
        if !fileExists || isDirectory {
            return <FileNotFound>{
                body: {message: "Source file does not exist or is not a regular file", path: sourceFilePath}
            };
        }

        file:MetaData|file:Error metaDataResult = file:getMetaData(sourceFilePath);
        if metaDataResult is file:Error {
            return <http:InternalServerError>{
                body: {message: metaDataResult.message(), path: sourceFilePath}
            };
        }
        file:MetaData metaData = metaDataResult;
        int fileSizeBytes = metaData.size;
        string lastModified = time:utcToString(metaData.modifiedTime);

        string|file:Error baseNameResult = file:basename(sourceFilePath);
        if baseNameResult is file:Error {
            return <http:InternalServerError>{
                body: {message: baseNameResult.message(), path: sourceFilePath}
            };
        }
        string fileName = baseNameResult;

        int? lastSeparatorIndex = sourceFilePath.lastIndexOf(file:pathSeparator);
        string parentDir = lastSeparatorIndex is int ? sourceFilePath.substring(0, lastSeparatorIndex) : ".";
        string processingDir = parentDir + file:pathSeparator + "processing";

        boolean|file:Error processingDirExistsResult = file:test(processingDir, file:EXISTS);
        if processingDirExistsResult is file:Error {
            return <http:InternalServerError>{
                body: {message: processingDirExistsResult.message(), path: processingDir}
            };
        }
        boolean processingDirExists = processingDirExistsResult;
        if !processingDirExists {
            file:Error? createDirResult = file:createDir(processingDir, file:RECURSIVE);
            if createDirResult is file:Error {
                return <http:InternalServerError>{
                    body: {message: createDirResult.message(), path: processingDir}
                };
            }
        }

        string destinationPath = processingDir + file:pathSeparator + fileName;
        file:Error? renameResult = file:rename(sourceFilePath, destinationPath);
        if renameResult is file:Error {
            return <http:InternalServerError>{
                body: {message: renameResult.message(), path: sourceFilePath}
            };
        }

        return {
            fileName,
            fileSizeBytes,
            lastModified,
            documentType: processRequest.documentType,
            status: "processing"
        };
    }

    resource function post archive(ArchiveRequest archiveRequest) returns ArchiveResponse|FileNotFound|http:InternalServerError {
        string processingFilePath = archiveRequest.processingFilePath;

        boolean|file:Error existsResult = file:test(processingFilePath, file:EXISTS);
        if existsResult is file:Error {
            return <http:InternalServerError>{
                body: {message: existsResult.message(), path: processingFilePath}
            };
        }
        boolean fileExists = existsResult;
        if !fileExists {
            return <FileNotFound>{
                body: {message: "Processing file does not exist", path: processingFilePath}
            };
        }

        int? lastSeparatorIndex = processingFilePath.lastIndexOf(file:pathSeparator);
        string parentDir = lastSeparatorIndex is int ? processingFilePath.substring(0, lastSeparatorIndex) : ".";

        string|file:Error archiveDirResult = file:joinPath(parentDir, "archive", archiveRequest.archiveDateFolder);
        if archiveDirResult is file:Error {
            return <http:InternalServerError>{
                body: {message: archiveDirResult.message(), path: processingFilePath}
            };
        }
        string archiveDir = archiveDirResult;

        boolean|file:Error archiveDirExistsResult = file:test(archiveDir, file:EXISTS);
        if archiveDirExistsResult is file:Error {
            return <http:InternalServerError>{
                body: {message: archiveDirExistsResult.message(), path: archiveDir}
            };
        }
        boolean archiveDirExists = archiveDirExistsResult;
        if !archiveDirExists {
            file:Error? createDirResult = file:createDir(archiveDir, file:RECURSIVE);
            if createDirResult is file:Error {
                return <http:InternalServerError>{
                    body: {message: createDirResult.message(), path: archiveDir}
                };
            }
        }

        string|file:Error baseNameResult = file:basename(processingFilePath);
        if baseNameResult is file:Error {
            return <http:InternalServerError>{
                body: {message: baseNameResult.message(), path: processingFilePath}
            };
        }
        string fileName = baseNameResult;

        string|file:Error archivedPathResult = file:joinPath(archiveDir, fileName);
        if archivedPathResult is file:Error {
            return <http:InternalServerError>{
                body: {message: archivedPathResult.message(), path: archiveDir}
            };
        }
        string archivedPath = archivedPathResult;

        file:Error? copyResult = file:copy(processingFilePath, archivedPath, file:REPLACE_EXISTING);
        if copyResult is file:Error {
            return <http:InternalServerError>{
                body: {message: copyResult.message(), path: processingFilePath}
            };
        }

        file:Error? removeResult = file:remove(processingFilePath);
        if removeResult is file:Error {
            return <http:InternalServerError>{
                body: {message: removeResult.message(), path: processingFilePath}
            };
        }

        return {
            originalPath: processingFilePath,
            archivedPath,
            archivedAt: time:utcToString(time:utcNow())
        };
    }

    resource function post 'error(ErrorMoveRequest errorMoveRequest) returns ErrorMoveResponse|FileNotFound|http:InternalServerError {
        string processingFilePath = errorMoveRequest.processingFilePath;

        boolean|file:Error existsResult = file:test(processingFilePath, file:EXISTS);
        if existsResult is file:Error {
            return <http:InternalServerError>{
                body: {message: existsResult.message(), path: processingFilePath}
            };
        }
        boolean fileExists = existsResult;
        if !fileExists {
            return <FileNotFound>{
                body: {message: "Processing file does not exist", path: processingFilePath}
            };
        }

        int? lastSeparatorIndex = processingFilePath.lastIndexOf(file:pathSeparator);
        string parentDir = lastSeparatorIndex is int ? processingFilePath.substring(0, lastSeparatorIndex) : ".";
        string errorDir = parentDir + file:pathSeparator + "error";

        boolean|file:Error errorDirExistsResult = file:test(errorDir, file:EXISTS);
        if errorDirExistsResult is file:Error {
            return <http:InternalServerError>{
                body: {message: errorDirExistsResult.message(), path: errorDir}
            };
        }
        boolean errorDirExists = errorDirExistsResult;
        if !errorDirExists {
            file:Error? createDirResult = file:createDir(errorDir, file:RECURSIVE);
            if createDirResult is file:Error {
                return <http:InternalServerError>{
                    body: {message: createDirResult.message(), path: errorDir}
                };
            }
        }

        string|file:Error baseNameResult = file:basename(processingFilePath);
        if baseNameResult is file:Error {
            return <http:InternalServerError>{
                body: {message: baseNameResult.message(), path: processingFilePath}
            };
        }
        string fileName = baseNameResult;

        string errorPath = errorDir + file:pathSeparator + fileName;
        file:Error? renameResult = file:rename(processingFilePath, errorPath);
        if renameResult is file:Error {
            return <http:InternalServerError>{
                body: {message: renameResult.message(), path: processingFilePath}
            };
        }

        return {
            fileName,
            errorPath,
            movedAt: time:utcToString(time:utcNow())
        };
    }

    resource function get folders/stats(string folderPath) returns FolderStats|FileNotFound|http:InternalServerError {
        boolean|file:Error existsResult = file:test(folderPath, file:EXISTS);
        if existsResult is file:Error {
            return <http:InternalServerError>{
                body: {message: existsResult.message(), path: folderPath}
            };
        }
        boolean folderExists = existsResult;
        if !folderExists {
            return <FileNotFound>{
                body: {message: "Folder does not exist", path: folderPath}
            };
        }

        file:MetaData[]|file:Error entriesResult = file:readDir(folderPath);
        if entriesResult is file:Error {
            return <http:InternalServerError>{
                body: {message: entriesResult.message(), path: folderPath}
            };
        }
        file:MetaData[] entries = entriesResult;

        int totalFiles = 0;
        int totalSizeBytes = 0;
        string largestFileName = "";
        int largestFileSizeBytes = -1;
        string oldestFileName = "";
        int oldestModifiedSeconds = -1;
        string newestFileName = "";
        int newestModifiedSeconds = -1;

        foreach file:MetaData entry in entries {
            file:MetaData|file:Error metaDataResult = file:getMetaData(entry.absPath);
            if metaDataResult is file:Error {
                return <http:InternalServerError>{
                    body: {message: metaDataResult.message(), path: entry.absPath}
                };
            }
            file:MetaData metaData = metaDataResult;
            if metaData.dir {
                continue;
            }

            string|file:Error entryFileNameResult = file:basename(metaData.absPath);
            if entryFileNameResult is file:Error {
                return <http:InternalServerError>{
                    body: {message: entryFileNameResult.message(), path: metaData.absPath}
                };
            }
            string entryFileName = entryFileNameResult;

            totalFiles += 1;
            totalSizeBytes += metaData.size;

            if metaData.size > largestFileSizeBytes {
                largestFileSizeBytes = metaData.size;
                largestFileName = entryFileName;
            }

            int modifiedSeconds = metaData.modifiedTime[0];
            if oldestModifiedSeconds == -1 || modifiedSeconds < oldestModifiedSeconds {
                oldestModifiedSeconds = modifiedSeconds;
                oldestFileName = entryFileName;
            }
            if newestModifiedSeconds == -1 || modifiedSeconds > newestModifiedSeconds {
                newestModifiedSeconds = modifiedSeconds;
                newestFileName = entryFileName;
            }
        }

        if totalFiles == 0 {
            largestFileSizeBytes = 0;
        }

        return {
            totalFiles,
            totalSizeBytes,
            largestFileName,
            largestFileSizeBytes,
            oldestFileName,
            newestFileName
        };
    }
}
