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
