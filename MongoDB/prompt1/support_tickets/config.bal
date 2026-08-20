// HTTP listener configuration.
configurable int servicePort = 8080;

// MongoDB server connection configuration.
configurable string mongoHost = "localhost";
configurable int mongoPort = 27017;
configurable string mongoDatabaseName = "support";
configurable string mongoUsername = ?;
configurable string mongoPassword = ?;
configurable string mongoAuthDatabase = "admin";

// TLS configuration: client certificate (key store) and server CA trust (trust store).
configurable string mongoKeyStorePath = ?;
configurable string mongoKeyStorePassword = ?;
configurable string mongoTrustStorePath = ?;
configurable string mongoTrustStorePassword = ?;

// Retry configuration for transient write failures.
configurable int maxWriteRetries = 3;
configurable decimal retryBaseDelaySeconds = 0.3;
