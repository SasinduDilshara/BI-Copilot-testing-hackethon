import ballerinax/nats;

final nats:Client natsClient = check new (natsUrl, connectionName = connectionName);

final nats:JetStreamClient jetStreamClient = check new (natsClient);
