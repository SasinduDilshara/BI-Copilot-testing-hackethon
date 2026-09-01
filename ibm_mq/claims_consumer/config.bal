// IBM MQ queue manager connection configurations.
configurable string queueManagerName = ?;
configurable string host = ?;
configurable int port = ?;
configurable string channel = ?;
configurable string userID = ?;
configurable string password = ?;

// Inbound queue on which claim submissions are received.
configurable string claimsInboundQueueName = "CLAIMS.INBOUND";

// Dead-letter queue for claims that exceed the maximum delivery attempts.
configurable string claimsDlqName = "CLAIMS.DLQ";

// Maximum number of delivery attempts before a claim is treated as a
// poison message and routed to the dead-letter queue.
configurable int maxDeliveryAttempts = 5;
