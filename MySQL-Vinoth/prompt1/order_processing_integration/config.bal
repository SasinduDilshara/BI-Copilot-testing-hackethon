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

// Connection pool sizing suitable for a long-running service handling
// concurrent requests. Each of the primary and replica clients gets its own
// pool sized with these settings since they connect to different hosts.
configurable int dbMaxOpenConnections = 25;
configurable int dbMinIdleConnections = 5;
configurable decimal dbMaxConnectionLifeTimeSeconds = 1800;
configurable decimal dbConnectionTimeoutSeconds = 30;

// Validates the connection pool sizing configuration before it is used to
// build the shared connection pool. Returns a specific, descriptive error
// when the configuration is invalid so the service fails fast at startup
// instead of surfacing an opaque driver-level error later.
function validatePoolConfig() returns error? {
    if dbMaxOpenConnections <= 0 {
        return error(string `Invalid database configuration: dbMaxOpenConnections must be a positive value, got ${dbMaxOpenConnections}`);
    }
    if dbMinIdleConnections < 0 {
        return error(string `Invalid database configuration: dbMinIdleConnections must not be negative, got ${dbMinIdleConnections}`);
    }
    if dbMinIdleConnections > dbMaxOpenConnections {
        return error(string `Invalid database configuration: dbMinIdleConnections (${dbMinIdleConnections}) must not exceed dbMaxOpenConnections (${dbMaxOpenConnections})`);
    }
    if dbMaxConnectionLifeTimeSeconds < 0d {
        return error(string `Invalid database configuration: dbMaxConnectionLifeTimeSeconds must not be negative, got ${dbMaxConnectionLifeTimeSeconds}`);
    }
    if dbConnectionTimeoutSeconds <= 0d {
        return error(string `Invalid database configuration: dbConnectionTimeoutSeconds must be a positive value, got ${dbConnectionTimeoutSeconds}`);
    }
    return ();
}
