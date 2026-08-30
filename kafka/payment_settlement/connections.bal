import ballerinax/kafka;

const string PAYMENTS_AUTHORIZED_TOPIC = "payments.authorized";
const string PAYMENTS_SETTLEMENT_TOPIC = "payments.settlement";
const string PAYMENT_SETTLEMENT_GROUP = "payment-settlement-service";

// Transactional producer configured for exactly-once semantics: idempotence
// on, acks=all, and a stable transactional ID so records published within a
// transaction are only visible to read-committed consumers once committed.
final kafka:Producer paymentSettlementProducer = check new (kafkaBootstrapServers, {
    clientId: "payment-settlement-producer",
    acks: "all",
    enableIdempotence: true,
    transactionalId: paymentSettlementTransactionalId
});

kafka:ConsumerConfiguration paymentAuthorizedConsumerConfiguration = {
    groupId: PAYMENT_SETTLEMENT_GROUP,
    topics: [PAYMENTS_AUTHORIZED_TOPIC],
    offsetReset: "earliest",
    autoCommit: false,
    isolationLevel: "read_committed",
    pollingInterval: 1
};

listener kafka:Listener paymentAuthorizedListener = new (kafkaBootstrapServers, paymentAuthorizedConsumerConfiguration);

// Synchronous consumer used only for the health endpoint's offset/lag lookups.
// It is never subscribed via the consumer group; partitions are assigned
// manually so it does not interfere with the group's partition balance. It is
// never used to poll or seek, only to query offset metadata.
final kafka:Consumer settlementMonitoringConsumer = check new (kafkaBootstrapServers, {
    clientId: "payment-settlement-monitoring",
    isolationLevel: "read_committed",
    autoCommit: false
});

// Bounded, insertion-ordered history of the last N settled payments, used to
// back the status endpoint. Oldest entries are evicted first once
// `settledPaymentsHistorySize` is reached, so the store cannot grow unbounded.
final SettledPaymentHistory settledPaymentHistory = new (settledPaymentsHistorySize);
