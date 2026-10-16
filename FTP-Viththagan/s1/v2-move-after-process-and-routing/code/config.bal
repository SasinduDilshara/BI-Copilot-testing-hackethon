// SFTP server connection details.
configurable string sftpHost = ?;
configurable int sftpPort = 22;
configurable string sftpUsername = ?;

// SSH private key based authentication (no hardcoded secrets).
configurable string sftpPrivateKeyPath = ?;
configurable string sftpPrivateKeyPassword = ?;

// Known-hosts file used to verify the SFTP server's identity.
configurable string sftpKnownHostsPath = ?;

// Remote drop directory that is polled for incoming partner order CSV files
// and the polling interval (in seconds).
configurable string ordersDropPath = ?;
configurable decimal pollingInterval = 60;

// Directories that successfully and unsuccessfully processed files are moved
// to, so they are not re-picked on the next poll.
configurable string processedDirPath = ?;
configurable string errorDirPath = ?;
