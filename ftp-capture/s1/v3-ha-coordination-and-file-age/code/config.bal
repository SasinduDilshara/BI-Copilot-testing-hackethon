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

// Minimum file age (in seconds) before a dropped file is considered stable
// enough to process, so files still being uploaded are not picked up.
configurable decimal minFileAge = 30;

// Distributed coordination settings so only one of the multiple listener
// instances actively polls at a time, while the others remain warm standbys.
configurable string coordinationMemberId = ?;
configurable string coordinationGroup = ?;
configurable int coordinationHeartbeatFrequency = 1;
configurable int coordinationLivenessCheckInterval = 30;

// Shared coordination database connection details used to elect the active
// listener instance among the warm-standby group.
configurable string coordinationDbHost = ?;
configurable int coordinationDbPort = 3306;
configurable string coordinationDbUser = ?;
configurable string coordinationDbPassword = ?;
configurable string coordinationDbName = ?;
