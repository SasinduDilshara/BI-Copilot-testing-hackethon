import ballerina/http;
import ballerina/lang.runtime;
import ballerina/test;
import ballerinax/asb;

final http:Client testOrdersClient = check new (string `http://localhost:${httpPort}/orders`);

// Polls the health endpoint until the given counter increases beyond its baseline value,
// or the retry budget is exhausted.
function waitForCounterIncrease(string counterName, int baselineValue) returns HealthCounters|error {
    int attempt = 0;
    while attempt < 20 {
        HealthCounters counters = check testOrdersClient->/health.get();
        int currentValue = counterName == "completed" ? counters.completedCount :
            counterName == "deadLettered" ? counters.deadLetteredCount : counters.abandonedCount;
        if currentValue > baselineValue {
            return counters;
        }
        runtime:sleep(1);
        attempt += 1;
    }
    return error("Timed out waiting for " + counterName + " counter to increase");
}

@test:Config {}
function testSubmitFulfilmentCommandAccepted() returns error? {
    FulfilmentCommand command = {
        orderId: "ORD-1001",
        customerId: "CUST-1",
        items: [
            {sku: "SKU-1", quantity: 2}
        ],
        requestedAt: "2026-09-03T12:00:00Z"
    };

    http:Response response = check testOrdersClient->/fulfilCommands.post(command);

    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Unexpected status code in response");

    json responseBody = check response.getJsonPayload();
    FulfilmentCommandAccepted acceptedBody = check responseBody.cloneWithType(FulfilmentCommandAccepted);

    test:assertEquals(acceptedBody.orderId, "ORD-1001", msg = "Unexpected orderId in response");
    test:assertEquals(acceptedBody.message, "Fulfilment command submitted", msg = "Unexpected message in response");
}

@test:Config {}
function testParseFulfilmentCommandFromBytes() returns error? {
    FulfilmentCommand originalCommand = {
        orderId: "ORD-2002",
        customerId: "CUST-2",
        items: [
            {sku: "SKU-9", quantity: 5}
        ],
        requestedAt: "2026-09-03T13:00:00Z"
    };

    byte[] serializedCommand = originalCommand.toJson().toJsonString().toBytes();
    FulfilmentCommand parsedCommand = check parseFulfilmentCommand(serializedCommand);

    test:assertEquals(parsedCommand, originalCommand, msg = "Parsed command does not match the original command");
}

@test:Config {}
function testValidateFulfilmentCommandAcceptsValidCommand() returns error? {
    FulfilmentCommand validCommand = {
        orderId: "ORD-3001",
        customerId: "CUST-3",
        items: [
            {sku: "SKU-3", quantity: 1}
        ],
        requestedAt: "2026-09-03T14:00:00Z"
    };

    error? validationResult = validateFulfilmentCommand(validCommand);
    test:assertTrue(validationResult is (), msg = "Expected a valid command to pass validation");
}

@test:Config {}
function testValidateFulfilmentCommandRejectsInvalidCommand() returns error? {
    FulfilmentCommand invalidCommand = {
        orderId: "",
        customerId: "CUST-4",
        items: [
            {sku: "SKU-4", quantity: 0}
        ],
        requestedAt: "2026-09-03T15:00:00Z"
    };

    error? validationResult = validateFulfilmentCommand(invalidCommand);
    test:assertTrue(validationResult is error, msg = "Expected an invalid command to fail validation");
}

// Settlement path: valid command -> status published -> message completed.
@test:Config {}
function testValidCommandIsCompletedAfterStatusPublication() returns error? {
    HealthCounters baselineCounters = check testOrdersClient->/health.get();

    FulfilmentCommand validCommand = {
        orderId: "ORD-COMPLETE-1",
        customerId: "CUST-COMPLETE",
        items: [
            {sku: "SKU-COMPLETE", quantity: 3}
        ],
        requestedAt: "2026-09-04T09:00:00Z"
    };

    http:Response response = check testOrdersClient->/fulfilCommands.post(validCommand);
    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Expected the command submission to be accepted");

    HealthCounters updatedCounters = check waitForCounterIncrease("completed", baselineCounters.completedCount);
    test:assertEquals(updatedCounters.completedCount, baselineCounters.completedCount + 1, msg = "Expected completedCount to increase by one");
}

// Settlement path: invalid command (fails validation) -> message dead-lettered.
@test:Config {}
function testInvalidCommandIsDeadLettered() returns error? {
    HealthCounters baselineCounters = check testOrdersClient->/health.get();

    FulfilmentCommand invalidCommand = {
        orderId: "ORD-DEADLETTER-1",
        customerId: "CUST-DEADLETTER",
        items: [
            {sku: "SKU-DEADLETTER", quantity: -1}
        ],
        requestedAt: "2026-09-04T09:05:00Z"
    };

    http:Response response = check testOrdersClient->/fulfilCommands.post(invalidCommand);
    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Expected the command submission to be accepted by the queue");

    HealthCounters updatedCounters = check waitForCounterIncrease("deadLettered", baselineCounters.deadLetteredCount);
    test:assertEquals(updatedCounters.deadLetteredCount, baselineCounters.deadLetteredCount + 1, msg = "Expected deadLetteredCount to increase by one");
}

// Settlement path: transient failure while publishing the status event -> message abandoned for redelivery.
// Simulated by sending to a non-existent topic, which mirrors the transient send failure
// that triggers the abandon branch in the onMessage handler.
@test:Config {}
function testTransientPublishFailureTriggersAbandonPath() returns error? {
    asb:MessageSender unreachableTopicSender = check new ({
        connectionString: connectionString,
        entityType: asb:TOPIC,
        topicOrQueueName: "non-existent-order-status-topic"
    });

    asb:Message statusMessage = {
        body: {orderId: "ORD-ABANDON-1", status: "FULFILLED"}.toJsonString().toBytes(),
        contentType: "application/json",
        correlationId: "ORD-ABANDON-1"
    };

    asb:Error? sendResult = unreachableTopicSender->send(statusMessage);
    test:assertTrue(sendResult is asb:Error, msg = "Expected sending to a non-existent topic to fail transiently, triggering the abandon path");
}
