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

// Validates a FulfilmentCommand. Returns an error describing the first validation
// failure found, or () when the command is valid.
function validateFulfilmentCommand(FulfilmentCommand command) returns error? {
    if command.orderId.trim().length() == 0 {
        return error("orderId must not be empty");
    }
    if command.customerId.trim().length() == 0 {
        return error("customerId must not be empty");
    }
    if command.requestedAt.trim().length() == 0 {
        return error("requestedAt must not be empty");
    }
    if command.items.length() == 0 {
        return error("items must not be empty");
    }
    foreach FulfilmentItem item in command.items {
        if item.sku.trim().length() == 0 {
            return error("item sku must not be empty");
        }
        if item.quantity <= 0 {
            return error("item quantity must be greater than zero");
        }
    }
    return;
}

// Publishes a fulfilment status event to the order-status topic with the correlation id,
// content type, and region application property set so it can be matched by the
// regional subscription filter rule.
function publishFulfilmentStatus(FulfilmentStatus status, string correlationId, string statusRegion) returns error? {
    asb:Message statusMessage = {
        body: status.toJson().toJsonString().toBytes(),
        contentType: "application/json",
        correlationId: correlationId,
        applicationProperties: {
            properties: {region: statusRegion}
        }
    };
    check orderStatusSender->send(statusMessage);
    log:printInfo("Published fulfilment status", orderId = status.orderId, status = status.status, region = statusRegion);
}

// Provisions the orders-to-fulfil queue and order-status topic if they do not already exist,
// along with a regional subscription and filter rule on the order-status topic.
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

    check provisionRegionalSubscription();
}

// Provisions the regional subscription and its SQL filter rule on the order-status topic,
// scoping delivery to status events whose "region" application property matches the
// configured region.
function provisionRegionalSubscription() returns error? {
    boolean|asb:Error? subscriptionExists = asbAdmin->subscriptionExists(orderStatusTopic, regionalSubscriptionName);
    if subscriptionExists is asb:Error {
        return subscriptionExists;
    }

    boolean subscriptionAlreadyExisted = subscriptionExists is boolean && subscriptionExists;
    if !subscriptionAlreadyExisted {
        asb:SubscriptionProperties|asb:Error? createdSubscription = asbAdmin->createSubscription(orderStatusTopic, regionalSubscriptionName);
        if createdSubscription is asb:Error {
            return createdSubscription;
        }
        log:printInfo("Created regional subscription", subscriptionName = regionalSubscriptionName);
    }

    asb:SqlRule regionFilterRule = {
        filter: string `region = '${region}'`,
        action: string `SET region = '${region}'`
    };
    asb:RuleProperties|asb:Error? createdRule = asbAdmin->createRule(orderStatusTopic, regionalSubscriptionName, "regional-filter-rule", rule = regionFilterRule);
    if createdRule is asb:Error {
        string createRuleErrorMessage = createdRule.message();
        if createRuleErrorMessage.includes("already exists") {
            log:printInfo("Regional filter rule already exists", region = region);
            return;
        }
        return createdRule;
    }
    log:printInfo("Created regional filter rule", region = region);
}

// Dead-letters a message via the given caller with the given reason and description,
// recording the outcome in the health counters.
function deadLetterCommand(asb:Caller caller, string deadLetterReason, string deadLetterErrorDescription) returns error? {
    asb:Error? deadLetterResult = caller->deadLetter(deadLetterReason = deadLetterReason, deadLetterErrorDescription = deadLetterErrorDescription);
    if deadLetterResult is asb:Error {
        log:printError("Failed to dead-letter message", deadLetterResult, deadLetterReason = deadLetterReason);
        return deadLetterResult;
    }
    recordDeadLettered();
}

// Increments the completed settlement counter.
function recordCompleted() {
    lock {
        healthCounters.completedCount += 1;
    }
}

// Increments the dead-lettered settlement counter.
function recordDeadLettered() {
    lock {
        healthCounters.deadLetteredCount += 1;
    }
}

// Increments the abandoned settlement counter.
function recordAbandoned() {
    lock {
        healthCounters.abandonedCount += 1;
    }
}

// Returns a snapshot copy of the current health counters.
function getHealthCounters() returns HealthCounters {
    lock {
        return healthCounters.clone();
    }
}
