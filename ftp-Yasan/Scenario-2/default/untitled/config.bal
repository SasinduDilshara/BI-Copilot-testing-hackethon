// SFTP connection configuration for the partner order-intake pipeline.
// Secrets (private key path) are supplied via configuration, never hardcoded.
configurable string sftpHost = ?;
configurable int sftpPort = 22;
configurable string sftpUsername = ?;
configurable string sftpPrivateKeyPath = ?;
configurable string? sftpPrivateKeyPassword = ();

configurable string inboundPath = "/inbound";
configurable string processedPath = "/processed";
configurable string archivePath = "/archive";
configurable string errorPath = "/error";
