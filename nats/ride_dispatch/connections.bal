import ballerinax/nats;

final nats:Client natsClient = check new (natsUrl, connectionName = connectionName, retryConfig = natsRetryConfig,
    validation = true);
