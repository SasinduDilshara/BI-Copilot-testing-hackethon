configurable string dbHost = "localhost";
configurable int dbPort = 1521;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbDatabase = ?;

configurable int httpPort = 9090;

// Retry configuration for transient connection errors.
configurable int maxRetryAttempts = 3;
configurable decimal retryBaseDelaySeconds = 0.5;
