// Kafka broker connection details.
configurable string kafkaBootstrapServers = ?;

// Unique transactional ID for the exactly-once producer. Must be stable across
// restarts of the same logical producer instance so Kafka can fence zombies.
configurable string paymentSettlementTransactionalId = ?;

// Number of most-recently-settled payments to retain in memory for the status
// endpoint. Oldest entries are evicted first once this limit is reached.
configurable int settledPaymentsHistorySize = 1000;

// HTTP listener port for the reconciliation API.
configurable int reconciliationServicePort = 9090;
