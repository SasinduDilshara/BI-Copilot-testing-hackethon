// SQL Server host running the named instance. SQL Browser (UDP 1434) resolves the
// dynamic port for the named instance below, so no fixed port is configured.
configurable string sqlServerHost = ?;
configurable string sqlServerInstance = "SQLEXPRESS";

configurable string sqlServerUser = ?;
configurable string sqlServerPassword = ?;

configurable string workOrdersDatabase = "work_orders";

// Truststore used to validate the SQL Server certificate. Since the connection
// travels over a corporate network that is not fully trusted, encryption is
// mandatory and the server certificate must be validated against this truststore
// rather than trusting the driver defaults.
configurable string sqlServerTrustStorePath = ?;
configurable string sqlServerTrustStorePassword = ?;

// Retry configuration for the local work-order transaction.
configurable int maxTransactionRetries = 3;
configurable decimal retryBaseDelaySeconds = 0.5;

// Kafka cluster that carries compensating decrement-stock messages to the
// inventory service.
configurable string kafkaBootstrapServers = "localhost:9092";
configurable string decrementStockTopic = "inventory.decrement-stock";

// Base URL of the existing incidents webhook that pages on-call when the
// work-order completion transaction fails even after retries.
configurable string incidentsServiceUrl = ?;
