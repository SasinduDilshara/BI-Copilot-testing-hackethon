// IBM MQ queue manager connection configurations.
configurable string queueManagerName = ?;
configurable string host = ?;
configurable int port = ?;
configurable string channel = ?;
configurable string userID = ?;
configurable string password = ?;

// Target queue for payment instructions.
configurable string paymentInstructionsQueueName = "PAYMENT.INSTRUCTIONS";

// Queue on which payment responses are received.
configurable string paymentResponsesQueueName = "PAYMENT.RESPONSES";

// HTTP listener port.
configurable int servicePort = 8080;
