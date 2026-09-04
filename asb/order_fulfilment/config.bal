// Azure Service Bus connection string (shared access policy connection string).
configurable string connectionString = ?;

// Queue that carries incoming fulfilment commands.
configurable string ordersToFulfilQueue = "orders-to-fulfil";

// Topic that carries outgoing fulfilment status events.
configurable string orderStatusTopic = "order-status";

// HTTP listener port for the test submission endpoint.
configurable int httpPort = 8080;

// Region used to create the regional subscription filter rule on the order-status topic.
configurable string region = "US";

// Name of the regional subscription created on the order-status topic.
configurable string regionalSubscriptionName = "order-status-regional-sub";
