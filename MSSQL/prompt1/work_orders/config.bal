// SQL Server host running the named instance. SQL Browser (UDP 1434) resolves the
// dynamic port for the named instance below, so no fixed port is configured.
configurable string sqlServerHost = ?;
configurable string sqlServerInstance = "SQLEXPRESS";

configurable string sqlServerUser = ?;
configurable string sqlServerPassword = ?;

configurable string workOrdersDatabase = "work_orders";
configurable string partsInventoryDatabase = "parts_inventory";

// Truststore used to validate the SQL Server certificate. Since the connection
// travels over a corporate network that is not fully trusted, encryption is
// mandatory and the server certificate must be validated against this truststore
// rather than trusting the driver defaults.
configurable string sqlServerTrustStorePath = ?;
configurable string sqlServerTrustStorePassword = ?;

// Retry configuration for the distributed transaction.
configurable int maxTransactionRetries = 3;
configurable decimal retryBaseDelaySeconds = 0.5;
