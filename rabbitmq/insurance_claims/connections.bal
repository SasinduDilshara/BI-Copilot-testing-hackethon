import ballerina/log;
import ballerinax/rabbitmq;

final rabbitmq:Client rabbitmqClient = check new (rabbitmqHost, rabbitmqPort, connectionData = {
    username: rabbitmqUsername,
    password: rabbitmqPassword,
    virtualHost: rabbitmqVhost
});

// Shared listener for all claim intake consumer services, with configurable prefetch (QoS).
listener rabbitmq:Listener claimsQueueListener = new (rabbitmqHost, rabbitmqPort, {
    prefetchCount: consumerPrefetchCount
}, {
    username: rabbitmqUsername,
    password: rabbitmqPassword,
    virtualHost: rabbitmqVhost
});

function initClaimsTopology() returns error? {
    // Main topic exchange that claim submissions are published to.
    check rabbitmqClient->exchangeDeclare(CLAIMS_EXCHANGE, rabbitmq:TOPIC_EXCHANGE, {durable: true});

    // Dead-letter exchange that rejected/exhausted messages are routed through.
    check rabbitmqClient->exchangeDeclare(CLAIMS_DLX_EXCHANGE, rabbitmq:TOPIC_EXCHANGE, {durable: true});

    // Terminal dead-letter queue, catches everything published to the DLX.
    check declareQueue(CLAIMS_DEAD_LETTER_QUEUE, {durable: true});
    check rabbitmqClient->queueBind(CLAIMS_DEAD_LETTER_QUEUE, CLAIMS_DLX_EXCHANGE, CLAIMS_DEAD_LETTER_BINDING_KEY);

    // Retry queue: messages sit here for `retryTtlMillis` then dead-letter back into the main
    // exchange (using their original routing key) for a delayed reprocessing attempt.
    check declareQueue(CLAIMS_RETRY_QUEUE, {
        durable: true,
        arguments: {
            [ARG_DEAD_LETTER_EXCHANGE]: CLAIMS_EXCHANGE,
            [ARG_MESSAGE_TTL]: retryTtlMillis
        }
    });

    // Single claim intake queue: on nack(requeue = false) messages are dead-lettered into the DLX.
    check declareQueue(CLAIMS_ALL_QUEUE, {
        durable: true,
        arguments: {
            [ARG_DEAD_LETTER_EXCHANGE]: CLAIMS_DLX_EXCHANGE
        }
    });
    check rabbitmqClient->queueBind(CLAIMS_ALL_QUEUE, CLAIMS_EXCHANGE, CLAIMS_ALL_BINDING_KEY);
}

# Creates a fresh, short-lived client/channel. Used for one-off operations that might fail
# with a channel-closing protocol error, so that failure never affects the long-lived
# `rabbitmqClient` used for publishing and for the rest of the topology setup.
#
# + return - a new client, or an error if the connection could not be established
function newShortLivedClient() returns rabbitmq:Client|rabbitmq:Error {
    return new (rabbitmqHost, rabbitmqPort, connectionData = {
        username: rabbitmqUsername,
        password: rabbitmqPassword,
        virtualHost: rabbitmqVhost
    });
}

# Declares a queue, self-healing when it already exists with different arguments. Both the
# initial attempt and the delete-and-retry step (on a PRECONDITION_FAILED mismatch) run on
# their own fresh, short-lived client, since any failed operation closes the AMQP channel it
# ran on and permanently poisons that client for further calls.
#
# + queueName - the name of the queue to declare
# + config - the queue configuration (durability, arguments, etc.)
# + return - () on success, or an error if the retry also fails
function declareQueue(string queueName, rabbitmq:QueueConfig config) returns error? {
    rabbitmq:Client declareClient = check newShortLivedClient();
    rabbitmq:Error? declareResult = declareClient->queueDeclare(queueName, config);
    if declareResult is () {
        log:printInfo(string `Declared queue '${queueName}' on first attempt.`);
        return;
    }

    log:printError(string `Initial declare failed for queue '${queueName}': ${declareResult.message()}`);
    string declareErrorMessage = declareResult.message();
    if !declareErrorMessage.includes("PRECONDITION_FAILED") {
        return declareResult;
    }

    log:printInfo(string `Queue '${queueName}' exists with different arguments; deleting it before recreating.`);
    rabbitmq:Client deleteClient = check newShortLivedClient();
    rabbitmq:Error? deleteResult = deleteClient->queueDelete(queueName);
    if deleteResult is rabbitmq:Error {
        log:printError(string `Delete failed for queue '${queueName}': ${deleteResult.message()}`);
        return deleteResult;
    }
    log:printInfo(string `Deleted queue '${queueName}'; redeclaring.`);

    rabbitmq:Client retryClient = check newShortLivedClient();
    rabbitmq:Error? retryResult = retryClient->queueDeclare(queueName, config);
    if retryResult is rabbitmq:Error {
        log:printError(string `Retry declare failed for queue '${queueName}': ${retryResult.message()}`);
        return retryResult;
    }
    log:printInfo(string `Redeclared queue '${queueName}' successfully.`);
}
