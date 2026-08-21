// HTTP listener configuration
configurable int servicePort = 8080;

// PostgreSQL database connection configuration
configurable string dbHost = ?;
configurable int dbPort = 5432;
configurable string dbUsername = ?;
configurable string dbName = ?;

// mTLS client certificate/key pair configuration (VERIFY-FULL)
configurable string dbClientCertPath = ?;
configurable string dbClientKeyPath = ?;
configurable string dbRootCertPath = ?;

// Connection pool configuration
configurable int dbMaxOpenConnections = 25;
configurable int dbMinIdleConnections = 5;
configurable decimal dbMaxConnectionLifeTime = 1800;

// Batch retry configuration
configurable int maxRetryAttempts = 3;
configurable decimal initialRetryBackoff = 0.4;
