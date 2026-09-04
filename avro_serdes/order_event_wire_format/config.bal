// Kafka broker configuration.
configurable string kafkaBootstrapServers = "localhost:9092";
configurable string kafkaTopic = "customer-profile";
configurable string consumerGroupId = "customer-profile-sync-group";

// Kafka authentication (SASL) configuration.
configurable string kafkaSaslUsername = ?;
configurable string kafkaSaslPassword = ?;

// Confluent Schema Registry configuration.
configurable string schemaRegistryUrl = ?;
configurable string schemaRegistryApiKey = ?;
configurable string schemaRegistryApiSecret = ?;

// Subject under which the CustomerProfile value schema is registered.
final string customerProfileValueSubject = "customer-profile-value";

// HTTP listener configuration for the schema promotion endpoint.
configurable int httpListenerPort = 8080;
