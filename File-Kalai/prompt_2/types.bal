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
