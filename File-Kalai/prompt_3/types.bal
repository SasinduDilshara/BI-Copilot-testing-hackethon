// Request payload for updating (creating/overwriting) a configuration file.
public type ConfigUpdateRequest record {|
    string content;
|};

// Response returned for configuration file read/write operations.
public type ConfigFileResponse record {|
    string environment;
    string fileName;
    string content;
    int fileSizeBytes;
    string lastModified;
|};
