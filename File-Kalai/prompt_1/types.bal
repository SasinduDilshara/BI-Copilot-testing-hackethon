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
