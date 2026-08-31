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

    // Lists all configuration files in an environment folder along with their metadata.
    resource function get [string environment]() returns EnvironmentConfigList|http:InternalServerError {
        string|file:Error environmentDirPath = file:joinPath(configBasePath, environment);
        if environmentDirPath is file:Error {
            return <http:InternalServerError>{body: string `Failed to construct directory path: ${environmentDirPath.message()}`};
        }

        file:MetaData[]|file:Error entries = file:readDir(environmentDirPath);
        if entries is file:Error {
            return <http:InternalServerError>{body: string `Failed to read environment directory: ${entries.message()}`};
        }

        ConfigFileSummary[] fileSummaries = [];
        foreach file:MetaData entry in entries {
            if entry.dir {
                continue;
            }

            string fileName = entry.absPath;
            int lastSeparatorIndex = fileName.lastIndexOf(file:pathSeparator) ?: -1;
            if lastSeparatorIndex >= 0 {
                fileName = fileName.substring(lastSeparatorIndex + 1);
            }

            string lastModified = time:utcToString(entry.modifiedTime);
            ConfigFileSummary configFileSummary = {
                fileName,
                fileSizeBytes: entry.size,
                lastModified
            };
            fileSummaries.push(configFileSummary);
        }

        EnvironmentConfigList environmentConfigList = {
            environment,
            configCount: fileSummaries.length(),
            files: fileSummaries
        };
        return environmentConfigList;
    }

    // Copies a configuration file from one environment to another.
    resource function post [string environment]/[string fileName]/copy(@http:Payload CopyConfigRequest copyConfigRequest) returns CopyConfigResponse|http:Conflict|http:InternalServerError {
        string|file:Error sourcePath = file:joinPath(configBasePath, environment, fileName);
        if sourcePath is file:Error {
            return <http:InternalServerError>{body: string `Failed to construct source file path: ${sourcePath.message()}`};
        }

        string targetEnvironment = copyConfigRequest.targetEnvironment;
        string|file:Error targetDirPath = file:joinPath(configBasePath, targetEnvironment);
        if targetDirPath is file:Error {
            return <http:InternalServerError>{body: string `Failed to construct target directory path: ${targetDirPath.message()}`};
        }

        boolean|file:Error targetDirExists = file:test(targetDirPath, file:EXISTS);
        if targetDirExists is file:Error {
            return <http:InternalServerError>{body: string `Failed to check target directory existence: ${targetDirExists.message()}`};
        }
        if !targetDirExists {
            file:Error? createDirResult = file:createDir(targetDirPath, file:RECURSIVE);
            if createDirResult is file:Error {
                return <http:InternalServerError>{body: string `Failed to create target environment directory: ${createDirResult.message()}`};
            }
        }

        string|file:Error destinationPath = file:joinPath(configBasePath, targetEnvironment, fileName);
        if destinationPath is file:Error {
            return <http:InternalServerError>{body: string `Failed to construct destination file path: ${destinationPath.message()}`};
        }

        boolean overwrite = copyConfigRequest.overwrite;
        boolean|file:Error destinationExists = file:test(destinationPath, file:EXISTS);
        if destinationExists is file:Error {
            return <http:InternalServerError>{body: string `Failed to check destination file existence: ${destinationExists.message()}`};
        }
        if !overwrite && destinationExists {
            CopyConflictError copyConflictError = {
                message: string `Destination file '${fileName}' already exists in environment '${targetEnvironment}'`,
                destinationPath
            };
            return <http:Conflict>{body: copyConflictError};
        }

        file:Error? copyResult = overwrite
            ? file:copy(sourcePath, destinationPath, file:REPLACE_EXISTING)
            : file:copy(sourcePath, destinationPath);
        if copyResult is file:Error {
            return <http:InternalServerError>{body: string `Failed to copy file: ${copyResult.message()}`};
        }

        CopyConfigResponse copyConfigResponse = {
            sourcePath,
            destinationPath,
            copiedAt: time:utcToString(time:utcNow())
        };
        return copyConfigResponse;
    }

    // Returns the stored configuration file change audit events.
    resource function get audit/events() returns ConfigAuditLog {
        ConfigChangeEvent[] events = getConfigChangeEvents();
        ConfigAuditLog configAuditLog = {
            totalEvents: events.length(),
            events
        };
        return configAuditLog;
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
