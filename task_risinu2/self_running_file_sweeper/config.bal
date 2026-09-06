// The folder that CSV order files are dropped into for processing.
configurable string inboxFolderPath = ?;

// The folder that successfully processed files are moved into.
configurable string processedFolderPath = ?;

// The folder that files which cannot be moved are placed into instead.
configurable string quarantineFolderPath = ?;

// How often, in seconds, the inbox folder is swept for new files.
configurable decimal sweepIntervalSeconds = ?;
