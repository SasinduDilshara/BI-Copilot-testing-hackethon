import ballerinax/rabbitmq;

# Parses the configured "host:port" failover address strings into `rabbitmq:Address` records.
# Returns `()` when no failover addresses are configured, matching the `Address[]|()` field type.
#
# + return - the parsed failover addresses, or () if none are configured
function buildFailoverAddresses() returns rabbitmq:Address[]|() {
    if rabbitmqFailoverAddresses.length() == 0 {
        return ();
    }
    rabbitmq:Address[] addresses = [];
    foreach string addressEntry in rabbitmqFailoverAddresses {
        string[] hostAndPort = re `:`.split(addressEntry);
        string host = hostAndPort[0];
        int port = hostAndPort.length() > 1 ? checkpanic int:fromString(hostAndPort[1]) : rabbitmqPort;
        addresses.push({host, port});
    }
    return addresses;
}

# Creates the shared client used for publishing reservation requests and reservation replies.
# Extracted into its own function (rather than an inline `new (...)` in the module-level
# declaration) so tests can replace it via compile-time function mocking without needing a
# live broker to be reachable.
#
# + return - a new RabbitMQ client, or an error if the connection could not be established
function initRabbitmqClient() returns rabbitmq:Client|error {
    return new (rabbitmqHost, rabbitmqPort, connectionData = {
        username: rabbitmqUsername,
        password: rabbitmqPassword,
        virtualHost: rabbitmqVhost,
        failoverAddresses: buildFailoverAddresses()
    });
}

final rabbitmq:Client rabbitmqClient = check initRabbitmqClient();

# Dedicated listener for the inventory reservation responder service.
listener rabbitmq:Listener inventoryQueueListener = new (rabbitmqHost, rabbitmqPort, connectionData = {
    username: rabbitmqUsername,
    password: rabbitmqPassword,
    virtualHost: rabbitmqVhost,
    failoverAddresses: buildFailoverAddresses()
});

# Dedicated listener for the fulfilment saga's reply consumer service.
listener rabbitmq:Listener repliesQueueListener = new (rabbitmqHost, rabbitmqPort, connectionData = {
    username: rabbitmqUsername,
    password: rabbitmqPassword,
    virtualHost: rabbitmqVhost,
    failoverAddresses: buildFailoverAddresses()
});

# Declares the durable, shared `fulfilment.replies` queue that inventory reservation replies are
# published back to. Unlike the previous request-reply flow, this queue is a well-known, durable
# queue (not a per-request exclusive one), since the reply consumer runs continuously and
# correlates replies to sagas using the message's correlation ID.
function initFulfilmentTopology() returns error? {
    check rabbitmqClient->queueDeclare(FULFILMENT_REPLIES_QUEUE, {durable: true});
}
