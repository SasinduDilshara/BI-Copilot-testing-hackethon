import ballerina/http;

// Request payload for the document processing endpoint.
public type ProcessRequest record {|
    string sourceFilePath;
    "csv"|"pdf" documentType;
|};

// Successful response after a document has been moved for processing.
public type ProcessResponse record {|
    string fileName;
    int fileSizeBytes;
    string lastModified;
    "csv"|"pdf" documentType;
    "processing" status;
|};

// Structured error detail payload.
public type ErrorDetail record {|
    string message;
    string path;
|};

// 404 response returned when the source file does not exist or is not a regular file.
public type FileNotFound record {|
    *http:NotFound;
    ErrorDetail body;
|};

// Request payload for the document archive endpoint.
public type ArchiveRequest record {|
    string processingFilePath;
    string archiveDateFolder;
|};

// Successful response after a document has been archived.
public type ArchiveResponse record {|
    string originalPath;
    string archivedPath;
    string archivedAt;
|};

// Request payload for the document error-move endpoint.
public type ErrorMoveRequest record {|
    string processingFilePath;
|};

// Successful response after a document has been moved to the error folder.
public type ErrorMoveResponse record {|
    string fileName;
    string errorPath;
    string movedAt;
|};
