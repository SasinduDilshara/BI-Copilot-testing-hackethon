import ballerinax/asb;

// Administrator client used to provision Service Bus entities.
final asb:Administrator asbAdmin = check new (connectionString);

// Sender used by the test HTTP endpoint to submit commands to the orders-to-fulfil queue.
final asb:MessageSender orderCommandSender = check new ({
    connectionString: connectionString,
    entityType: asb:QUEUE,
    topicOrQueueName: ordersToFulfilQueue
});

// Sender used to publish fulfilment status events to the order-status topic.
final asb:MessageSender orderStatusSender = check new ({
    connectionString: connectionString,
    entityType: asb:TOPIC,
    topicOrQueueName: orderStatusTopic
});

// Listener that receives fulfilment commands from the orders-to-fulfil queue.
listener asb:Listener orderCommandListener = check new (
    connectionString = connectionString,
    entityConfig = {
        queueName: ordersToFulfilQueue
    }
);
