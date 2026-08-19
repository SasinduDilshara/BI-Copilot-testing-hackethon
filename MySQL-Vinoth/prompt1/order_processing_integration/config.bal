// Primary database connection configurations.
// These are expected to be supplied via environment variables when
// running in Kubernetes (e.g. through a ConfigMap/Secret backed Config.toml
// or BAL_CONFIG_FILES/environment variable overrides).
configurable string primaryDbHost = ?;
configurable int primaryDbPort = 3306;

// Read-only replica connection configurations.
configurable string replicaOneDbHost = ?;
configurable int replicaOneDbPort = 3306;

configurable string replicaTwoDbHost = ?;
configurable int replicaTwoDbPort = 3306;

// Shared database credentials and schema name.
configurable string dbUsername = ?;
configurable string dbPassword = ?;
configurable string dbName = ?;

// Certificate-based TLS configuration (mutual/verify-identity SSL).
// The trust store validates the server certificate and the key store
// is used for the client certificate presented to the server.
configurable string dbTrustStorePath = ?;
configurable string dbTrustStorePassword = ?;
configurable string dbKeyStorePath = ?;
configurable string dbKeyStorePassword = ?;

// Connection pool sizing suitable for a long-running service.
configurable int dbMaxOpenConnections = 10;
configurable int dbMinIdleConnections = 2;
configurable decimal dbMaxConnectionLifeTimeSeconds = 1800;
