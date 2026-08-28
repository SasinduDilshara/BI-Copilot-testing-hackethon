// Solace PubSub+ broker connection configuration.
configurable string solaceBrokerUrl = ?;
configurable string solaceVpnName = ?;

// Basic authentication credentials for the broker connection.
configurable string solaceUsername = ?;
configurable string solacePassword = ?;

// HTTP listener configuration.
configurable int servicePort = 8091;

// Payment instructions queue configuration.
configurable string paymentInstructionsQueueName = "PAYMENTS.INSTRUCTIONS.IN";

// Settlement publishing configuration.
configurable string settlementOutQueueName = "PAYMENTS.SETTLEMENT.OUT";

// Dead letter queue for payment instructions that fail validation or exceed the redelivery limit.
configurable string paymentInstructionsDlqName = "PAYMENTS.INSTRUCTIONS.DLQ";

// Maximum number of delivery attempts (as reported by the broker's deliveryCount) before a
// payment instruction is treated as poison and routed to the dead letter queue instead of being
// retried again.
configurable int maxDeliveryCount = 5;
