import ballerina/file;
import ballerina/http;
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
}
