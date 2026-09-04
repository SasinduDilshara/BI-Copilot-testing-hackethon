import ballerina/log;
import ballerina/time;
import ballerinax/asb;

// Returns the current UTC timestamp in ISO 8601 format.
function getCurrentTimestamp() returns string {
    return time:utcToString(time:utcNow());
}

// Parses the raw message body received from the Service Bus queue into a FulfilmentCommand.
function parseFulfilmentCommand(anydata messageBody) returns FulfilmentCommand|error {
    if messageBody is byte[] {
        string jsonText = check string:fromBytes(messageBody);
        json commandJson = check jsonText.fromJsonString();
        return commandJson.cloneWithType(FulfilmentCommand);
    }
    return messageBody.cloneWithType(FulfilmentCommand);
}

// Publishes a fulfilment status event to the order-status topic with the correlation id
// and content type set.
function publishFulfilmentStatus(FulfilmentStatus status, string correlationId) returns error? {
    asb:Message statusMessage = {
        body: status.toJson().toJsonString().toBytes(),
        contentType: "application/json",
        correlationId: correlationId
    };
    check orderStatusSender->send(statusMessage);
    log:printInfo("Published fulfilment status", orderId = status.orderId, status = status.status);
}

// Provisions the orders-to-fulfil queue and order-status topic if they do not already exist.
function provisionServiceBusEntities() returns error? {
    boolean|asb:Error? queueExists = asbAdmin->queueExists(ordersToFulfilQueue);
    if queueExists is boolean && !queueExists {
        asb:QueueProperties|asb:Error? createdQueue = asbAdmin->createQueue(ordersToFulfilQueue);
        if createdQueue is asb:Error {
            return createdQueue;
        }
        log:printInfo("Created queue", queueName = ordersToFulfilQueue);
    } else if queueExists is asb:Error {
        return queueExists;
    }

    boolean|asb:Error? topicExists = asbAdmin->topicExists(orderStatusTopic);
    if topicExists is boolean && !topicExists {
        asb:TopicProperties|asb:Error? createdTopic = asbAdmin->createTopic(orderStatusTopic);
        if createdTopic is asb:Error {
            return createdTopic;
        }
        log:printInfo("Created topic", topicName = orderStatusTopic);
    } else if topicExists is asb:Error {
        return topicExists;
    }
}
