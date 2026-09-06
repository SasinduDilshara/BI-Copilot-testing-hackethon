// The folder that CSV order files are dropped into for processing.
configurable string inboxFolderPath = ?;

// The folder that successfully processed files are moved into.
configurable string processedFolderPath = ?;

// How often, in seconds, the inbox folder is swept for new files.
configurable decimal sweepIntervalSeconds = ?;

// RFC 3339 date-time at which the sweeper starts processing files.
configurable string processingWindowStart = ?;

// RFC 3339 date-time at which the sweeper stops processing files.
configurable string processingWindowEnd = ?;
