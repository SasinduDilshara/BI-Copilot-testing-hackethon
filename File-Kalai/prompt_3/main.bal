import ballerina/file;
import ballerina/http;
import ballerina/io;
import ballerina/time;

service /config on new http:Listener(7070) {

    // Reads a configuration file and returns its content along with metadata.
    resource function get [string environment]/[string fileName]() returns ConfigFileResponse|http:NotFound|http:InternalServerError {
        string|file:Error filePath = file:joinPath(configBasePath, environment, fileName);
        if filePath is file:Error {
            return <http:InternalServerError>{body: string `Failed to construct file path: ${filePath.message()}`};
        }

        boolean|file:Error fileExists = file:test(filePath, file:EXISTS);
        if fileExists is file:Error {
            return <http:InternalServerError>{body: string `Failed to check file existence: ${fileExists.message()}`};
        }
        if !fileExists {
            return <http:NotFound>{body: string `Configuration file '${fileName}' not found in environment '${environment}'`};
        }

        string|io:Error content = io:fileReadString(filePath);
        if content is io:Error {
            return <http:InternalServerError>{body: string `Failed to read file: ${content.message()}`};
        }

        file:MetaData|file:Error metaData = file:getMetaData(filePath);
        if metaData is file:Error {
            return <http:InternalServerError>{body: string `Failed to retrieve file metadata: ${metaData.message()}`};
        }

        string lastModified = time:utcToString(metaData.modifiedTime);

        ConfigFileResponse configFileResponse = {
            environment,
            fileName,
            content,
            fileSizeBytes: metaData.size,
            lastModified
        };
        return configFileResponse;
    }

    // Creates or updates a configuration file, creating the environment directory if needed.
    resource function put [string environment]/[string fileName](@http:Payload ConfigUpdateRequest configUpdateRequest) returns ConfigFileResponse|http:InternalServerError {
        string|file:Error environmentDirPath = file:joinPath(configBasePath, environment);
        if environmentDirPath is file:Error {
            return <http:InternalServerError>{body: string `Failed to construct directory path: ${environmentDirPath.message()}`};
        }

        boolean|file:Error dirExists = file:test(environmentDirPath, file:EXISTS);
        if dirExists is file:Error {
            return <http:InternalServerError>{body: string `Failed to check directory existence: ${dirExists.message()}`};
        }
        if !dirExists {
            file:Error? createDirResult = file:createDir(environmentDirPath, file:RECURSIVE);
            if createDirResult is file:Error {
                return <http:InternalServerError>{body: string `Failed to create environment directory: ${createDirResult.message()}`};
            }
        }

        string|file:Error filePath = file:joinPath(configBasePath, environment, fileName);
        if filePath is file:Error {
            return <http:InternalServerError>{body: string `Failed to construct file path: ${filePath.message()}`};
        }

        io:Error? writeResult = io:fileWriteString(filePath, configUpdateRequest.content);
        if writeResult is io:Error {
            return <http:InternalServerError>{body: string `Failed to write file: ${writeResult.message()}`};
        }

        file:MetaData|file:Error metaData = file:getMetaData(filePath);
        if metaData is file:Error {
            return <http:InternalServerError>{body: string `Failed to retrieve file metadata: ${metaData.message()}`};
        }

        string lastModified = time:utcToString(metaData.modifiedTime);

        ConfigFileResponse configFileResponse = {
            environment,
            fileName,
            content: configUpdateRequest.content,
            fileSizeBytes: metaData.size,
            lastModified
        };
        return configFileResponse;
    }

    // Deletes a configuration file.
    resource function delete [string environment]/[string fileName]() returns http:NoContent|http:NotFound|http:InternalServerError {
        string|file:Error filePath = file:joinPath(configBasePath, environment, fileName);
        if filePath is file:Error {
            return <http:InternalServerError>{body: string `Failed to construct file path: ${filePath.message()}`};
        }

        boolean|file:Error fileExists = file:test(filePath, file:EXISTS);
        if fileExists is file:Error {
            return <http:InternalServerError>{body: string `Failed to check file existence: ${fileExists.message()}`};
        }
        if !fileExists {
            return <http:NotFound>{body: string `Configuration file '${fileName}' not found in environment '${environment}'`};
        }

        file:Error? removeResult = file:remove(filePath);
        if removeResult is file:Error {
            return <http:InternalServerError>{body: string `Failed to delete file: ${removeResult.message()}`};
        }

        return <http:NoContent>{};
    }
}
