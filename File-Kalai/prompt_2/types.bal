// Request to create a new report generation workspace.
public type WorkspaceRequest record {|
    string reportId;
    "csv"|"pdf" reportType;
|};

// Response containing the created workspace directory details.
public type WorkspaceResponse record {|
    string reportId;
    string workspacePath;
    string dataPath;
    string outputPath;
    string createdAt;
|};

// Request to create a named data file inside the workspace's data/ subdirectory.
public type DataFileRequest record {|
    string fileName;
    string content;
|};

// Response containing the details of the created data file.
public type DataFileResponse record {|
    string reportId;
    string fileName;
    string filePath;
    int fileSizeBytes;
|};
