import ballerinax/rabbitmq;

# Creates the shared client used for publishing notifications and declaring topology. Extracted
# into its own function (rather than an inline `new (...)` in the module-level declaration) so
# tests can replace it via compile-time function mocking without needing a live broker to be
# reachable.
#
# + return - a new RabbitMQ client, or an error if the connection could not be established
function initRabbitmqClient() returns rabbitmq:Client|error {
    return new (rabbitmqHost, rabbitmqPort, connectionData = {
        username: rabbitmqUsername,
        password: rabbitmqPassword,
        virtualHost: rabbitmqVhost
    });
}

final rabbitmq:Client rabbitmqClient = check initRabbitmqClient();

# Dedicated listener for the email consumer, with its own prefetch (QoS) so a slow or
# backlogged email consumer cannot starve the push/urgent consumers.
listener rabbitmq:Listener emailQueueListener = new (rabbitmqHost, rabbitmqPort, {
    prefetchCount: emailPrefetchCount
}, {
    username: rabbitmqUsername,
    password: rabbitmqPassword,
    virtualHost: rabbitmqVhost
});

# Dedicated listener for the push consumer, with its own prefetch (QoS).
listener rabbitmq:Listener pushQueueListener = new (rabbitmqHost, rabbitmqPort, {
    prefetchCount: pushPrefetchCount
}, {
    username: rabbitmqUsername,
    password: rabbitmqPassword,
    virtualHost: rabbitmqVhost
});

# Dedicated listener for the urgent consumer, with its own prefetch (QoS).
listener rabbitmq:Listener urgentQueueListener = new (rabbitmqHost, rabbitmqPort, {
    prefetchCount: urgentPrefetchCount
}, {
    username: rabbitmqUsername,
    password: rabbitmqPassword,
    virtualHost: rabbitmqVhost
});

# Declares the `notifications.broadcast` direct exchange and the three durable, quorum
# destination queues (email, push, urgent) bound to it, each with a binding key equal to its
# own destination name. A direct exchange routes a published message only to the queue(s) whose
# binding key exactly matches the message's routing key, so urgency can pick the destination:
# publishing with routing key "urgent" reaches only `notifications.urgent`, while publishing
# with routing key "email"/"push" reaches only that channel's queue.
#
# Quorum queues are declared with `durable: true` and the `x-queue-type: quorum` argument.
function initNotificationsTopology() returns error? {
    check rabbitmqClient->exchangeDeclare(NOTIFICATIONS_EXCHANGE, rabbitmq:DIRECT_EXCHANGE, {durable: true});

    rabbitmq:QueueConfig quorumQueueConfig = {
        durable: true,
        arguments: {
            [ARG_QUEUE_TYPE]: QUEUE_TYPE_QUORUM
        }
    };

    check rabbitmqClient->queueDeclare(NOTIFICATIONS_EMAIL_QUEUE, quorumQueueConfig);
    check rabbitmqClient->queueDeclare(NOTIFICATIONS_PUSH_QUEUE, quorumQueueConfig);
    check rabbitmqClient->queueDeclare(NOTIFICATIONS_URGENT_QUEUE, quorumQueueConfig);

    check rabbitmqClient->queueBind(NOTIFICATIONS_EMAIL_QUEUE, NOTIFICATIONS_EXCHANGE, CHANNEL_EMAIL);
    check rabbitmqClient->queueBind(NOTIFICATIONS_PUSH_QUEUE, NOTIFICATIONS_EXCHANGE, CHANNEL_PUSH);
    check rabbitmqClient->queueBind(NOTIFICATIONS_URGENT_QUEUE, NOTIFICATIONS_EXCHANGE, CHANNEL_URGENT);
}
