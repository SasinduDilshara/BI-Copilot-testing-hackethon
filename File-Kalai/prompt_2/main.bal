import ballerina/file;
import ballerina/http;
import ballerina/io;
import ballerina/time;

service /reports on workspaceListener {

    resource function post workspace(@http:Payload WorkspaceRequest workspaceRequest)
            returns WorkspaceResponse|http:InternalServerError {

        string reportId = workspaceRequest.reportId;
        string tempDirPrefix = string `report-${reportId}-`;

        string|file:Error workspacePath = file:createTempDir(prefix = tempDirPrefix);
        if workspacePath is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to create workspace directory: ${workspacePath.message()}`
            };
        }

        lock {
            reportWorkspaces[reportId] = workspacePath;
        }

        string|file:Error dataPath = file:joinPath(workspacePath, "data");
        if dataPath is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to construct data path: ${dataPath.message()}`
            };
        }

        string|file:Error outputPath = file:joinPath(workspacePath, "output");
        if outputPath is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to construct output path: ${outputPath.message()}`
            };
        }

        file:Error? dataDirResult = file:createDir(dataPath);
        if dataDirResult is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to create data directory: ${dataDirResult.message()}`
            };
        }

        file:Error? outputDirResult = file:createDir(outputPath);
        if outputDirResult is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to create output directory: ${outputDirResult.message()}`
            };
        }

        string createdAt = time:utcToString(time:utcNow());

        return {
            reportId: reportId,
            workspacePath: workspacePath,
            dataPath: dataPath,
            outputPath: outputPath,
            createdAt: createdAt
        };
    }

    resource function post [string reportId]/data\-file(@http:Payload DataFileRequest dataFileRequest)
            returns DataFileResponse|http:NotFound|http:InternalServerError {

        string? workspacePath;
        lock {
            workspacePath = reportWorkspaces[reportId];
        }

        if workspacePath is () {
            return <http:NotFound>{
                body: string `Workspace not found for reportId: ${reportId}`
            };
        }

        string|file:Error dataPath = file:joinPath(workspacePath, "data");
        if dataPath is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to construct data path: ${dataPath.message()}`
            };
        }

        boolean|file:Error dataDirExists = file:test(dataPath, file:EXISTS);
        if dataDirExists is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to verify data directory: ${dataDirExists.message()}`
            };
        }
        if !dataDirExists {
            return <http:NotFound>{
                body: string `Data directory not found for reportId: ${reportId}`
            };
        }

        string fileName = dataFileRequest.fileName;
        string|file:Error filePath = file:joinPath(dataPath, fileName);
        if filePath is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to construct file path: ${filePath.message()}`
            };
        }

        file:Error? createResult = file:create(filePath);
        if createResult is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to create data file: ${createResult.message()}`
            };
        }

        io:Error? writeResult = io:fileWriteString(filePath, dataFileRequest.content);
        if writeResult is io:Error {
            return <http:InternalServerError>{
                body: string `Failed to write data file content: ${writeResult.message()}`
            };
        }

        file:MetaData&readonly|file:Error fileMetaData = file:getMetaData(filePath);
        if fileMetaData is file:Error {
            return <http:InternalServerError>{
                body: string `Failed to retrieve data file metadata: ${fileMetaData.message()}`
            };
        }

        return {
            reportId: reportId,
            fileName: fileName,
            filePath: filePath,
            fileSizeBytes: fileMetaData.size
        };
    }
}
