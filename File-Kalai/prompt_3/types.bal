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

// Request payload for copying a configuration file to another environment.
public type CopyConfigRequest record {|
    string targetEnvironment;
    boolean overwrite;
|};

// Response returned after successfully copying a configuration file.
public type CopyConfigResponse record {|
    string sourcePath;
    string destinationPath;
    string copiedAt;
|};

// Structured error payload returned when a copy operation conflicts with an existing file.
public type CopyConflictError record {|
    string message;
    string destinationPath;
|};

// Summary metadata for a single configuration file within an environment.
public type ConfigFileSummary record {|
    string fileName;
    int fileSizeBytes;
    string lastModified;
|};

// Response listing all configuration files within an environment.
public type EnvironmentConfigList record {|
    string environment;
    int configCount;
    ConfigFileSummary[] files;
|};

// Represents a single detected change to a configuration file on disk.
public type ConfigChangeEvent record {|
    string changeType;
    string filePath;
    string detectedAt;
|};

// Response containing the stored configuration change audit events.
public type ConfigAuditLog record {|
    int totalEvents;
    ConfigChangeEvent[] events;
|};
