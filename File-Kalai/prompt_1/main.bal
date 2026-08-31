import ballerina/file;
import ballerina/http;
import ballerina/time;

isolated map<string> reportWorkspaces = {};

listener http:Listener documentsListener = new (9093);

service /documents on documentsListener {

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
}

service /reports on documentsListener {

    resource function delete [string reportId]/workspace() returns http:NoContent|FileNotFound|http:InternalServerError {
        string? workspacePath = ();
        lock {
            workspacePath = reportWorkspaces[reportId];
        }
        if workspacePath is () {
            return <FileNotFound>{
                body: {message: "Workspace does not exist for the given report", path: reportId}
            };
        }
        string resolvedWorkspacePath = workspacePath;

        boolean|file:Error existsResult = file:test(resolvedWorkspacePath, file:EXISTS);
        if existsResult is file:Error {
            return <http:InternalServerError>{
                body: {message: existsResult.message(), path: resolvedWorkspacePath}
            };
        }
        boolean workspaceExists = existsResult;
        if !workspaceExists {
            return <FileNotFound>{
                body: {message: "Workspace does not exist", path: resolvedWorkspacePath}
            };
        }

        file:Error? removeResult = file:remove(resolvedWorkspacePath, file:RECURSIVE);
        if removeResult is file:Error {
            return <http:InternalServerError>{
                body: {message: removeResult.message(), path: resolvedWorkspacePath}
            };
        }

        lock {
            _ = reportWorkspaces.removeIfHasKey(reportId);
        }

        return http:NO_CONTENT;
    }

    resource function get [string reportId]/workspace/contents() returns WorkspaceContents|FileNotFound|http:InternalServerError {
        string? workspacePath = ();
        lock {
            workspacePath = reportWorkspaces[reportId];
        }
        if workspacePath is () {
            return <FileNotFound>{
                body: {message: "Workspace does not exist for the given report", path: reportId}
            };
        }
        string resolvedWorkspacePath = workspacePath;

        string|file:Error dataDirResult = file:joinPath(resolvedWorkspacePath, "data");
        if dataDirResult is file:Error {
            return <http:InternalServerError>{
                body: {message: dataDirResult.message(), path: resolvedWorkspacePath}
            };
        }
        string dataDir = dataDirResult;

        string|file:Error outputDirResult = file:joinPath(resolvedWorkspacePath, "output");
        if outputDirResult is file:Error {
            return <http:InternalServerError>{
                body: {message: outputDirResult.message(), path: resolvedWorkspacePath}
            };
        }
        string outputDir = outputDirResult;

        [string[], int]|file:Error dataResult = collectFilesRecursively(dataDir);
        if dataResult is file:Error {
            return <http:InternalServerError>{
                body: {message: dataResult.message(), path: dataDir}
            };
        }
        [string[], int] [dataFileNames, dataSizeBytes] = dataResult;

        [string[], int]|file:Error outputResult = collectFilesRecursively(outputDir);
        if outputResult is file:Error {
            return <http:InternalServerError>{
                body: {message: outputResult.message(), path: outputDir}
            };
        }
        [string[], int] [outputFileNames, outputSizeBytes] = outputResult;

        return {
            reportId,
            dataFiles: dataFileNames,
            outputFiles: outputFileNames,
            totalWorkspaceSizeBytes: dataSizeBytes + outputSizeBytes
        };
    }
}

function collectFilesRecursively(string directoryPath) returns [string[], int]|file:Error {
    boolean dirExists = check file:test(directoryPath, file:EXISTS);
    if !dirExists {
        return [[], 0];
    }

    string[] fileNames = [];
    int totalSizeBytes = 0;

    file:MetaData[] entries = check file:readDir(directoryPath);
    foreach file:MetaData entry in entries {
        if entry.dir {
            [string[], int] subResult = check collectFilesRecursively(entry.absPath);
            fileNames.push(...subResult[0]);
            totalSizeBytes += subResult[1];
        } else {
            string|file:Error entryFileName = file:basename(entry.absPath);
            if entryFileName is string {
                fileNames.push(entryFileName);
            }
            totalSizeBytes += entry.size;
        }
    }

    return [fileNames, totalSizeBytes];
}
