// ActiveMQ Artemis broker connection URL.
configurable string providerUrl = "tcp://localhost:61616";

// HTTP listener port for the REST API front door.
configurable int servicePort = 8080;

// Maximum number of redelivery attempts for a core-transfer response before it is routed to
// CORE.TRANSFER.DLQ instead of being processed further.
configurable int maxRedeliveryCount = 5;
