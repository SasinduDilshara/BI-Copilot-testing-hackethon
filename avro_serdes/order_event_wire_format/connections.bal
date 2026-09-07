import ballerinax/confluent.cregistry;
import ballerinax/kafka;

final kafka:ProducerConfiguration kafkaProducerConfig = {
    clientId: "customer-profile-producer",
    acks: "all",
    retryCount: 3,
    securityProtocol: "SASL_SSL",
    auth: {
        mechanism: "PLAIN",
        username: kafkaSaslUsername,
        password: kafkaSaslPassword
    }
};

final kafka:ConsumerConfiguration kafkaConsumerConfig = {
    groupId: consumerGroupId,
    topics: [kafkaTopic],
    offsetReset: "earliest",
    securityProtocol: "SASL_SSL",
    auth: {
        mechanism: "PLAIN",
        username: kafkaSaslUsername,
        password: kafkaSaslPassword
    }
};

final kafka:Producer customerProfileProducer = check new (kafkaBootstrapServers, kafkaProducerConfig);

final kafka:Consumer customerProfileConsumer = check new (kafkaBootstrapServers, kafkaConsumerConfig);

final cregistry:Client schemaRegistryClient = check new ({
    baseUrl: schemaRegistryUrl,
    originals: {
        "basic.auth.credentials.source": "USER_INFO",
        "basic.auth.user.info": string `${schemaRegistryApiKey}:${schemaRegistryApiSecret}`
    }
});

// The currently active CustomerProfile schema for the `customer-profile-value` subject. Compatibility
// validation is strictly read-only and never updates this value - it can only be changed through a
// separate, explicit administrative action outside of this flow.
isolated string activeCustomerProfileSchema = customerProfileAvroSchema;

// In-memory validation history of schema compatibility decisions (compatible and incompatible).
isolated CompatibilityValidationRecord[] compatibilityValidationHistory = [];
