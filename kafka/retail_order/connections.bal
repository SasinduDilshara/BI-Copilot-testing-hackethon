import ballerinax/kafka;

final kafka:Producer orderEventProducer = check new (kafkaBootstrapServers, {
    acks: "all",
    enableIdempotence: true,
    clientId: "order-enrichment-producer"
});
