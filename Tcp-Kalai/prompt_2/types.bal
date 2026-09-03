// Log level of a log entry.
type LogLevel "INFO"|"WARN"|"ERROR";

// A single log entry sent by a service over the TCP connection.
type LogEntry record {|
    string serviceId;
    LogLevel level;
    string message;
    string timestamp;
|};

// Tracks metadata about an active TCP log shipping connection.
type ConnectionInfo record {|
    string serviceId;
    string remoteHost;
    string connectedAt;
    int totalLinesReceived;
|};
