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
}
