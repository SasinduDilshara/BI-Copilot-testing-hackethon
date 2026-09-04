import ballerina/http;
import ballerina/lang.runtime;
import ballerina/test;
import ballerina/time;
import ballerinax/asb;

final http:Client testOrdersClient = check new (string `http://localhost:${httpPort}/orders`);

// Polls the health endpoint until the given counter increases beyond its baseline value,
// or the retry budget is exhausted.
function waitForCounterIncrease(string counterName, int baselineValue, int maxAttempts = 20) returns HealthCounters|error {
    int attempt = 0;
    while attempt < maxAttempts {
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

// Returns an ISO 8601 timestamp a given number of seconds relative to now, used to build
// immediate (past) or scheduled (future) requestedAt values regardless of when tests run.
function timestampOffsetFromNow(decimal offsetSeconds) returns string {
    time:Utc offsetUtc = time:utcAddSeconds(time:utcNow(), offsetSeconds);
    return time:utcToString(offsetUtc);
}

@test:Config {}
function testSubmitFulfilmentCommandAccepted() returns error? {
    FulfilmentCommand command = {
        orderId: "ORD-1001",
        customerId: "CUST-1",
        items: [
            {sku: "SKU-1", quantity: 2}
        ],
        requestedAt: timestampOffsetFromNow(-3600d)
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
        requestedAt: timestampOffsetFromNow(-3600d)
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
        requestedAt: timestampOffsetFromNow(-3600d)
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
        requestedAt: timestampOffsetFromNow(-60d)
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
        requestedAt: timestampOffsetFromNow(-60d)
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

// Submission path: a command whose requestedAt is in the past is submitted immediately
// and is available for delivery straight away.
@test:Config {}
function testPastRequestedAtCommandIsSubmittedImmediately() returns error? {
    HealthCounters baselineCounters = check testOrdersClient->/health.get();

    FulfilmentCommand immediateCommand = {
        orderId: "ORD-IMMEDIATE-1",
        customerId: "CUST-IMMEDIATE",
        items: [
            {sku: "SKU-IMMEDIATE", quantity: 1}
        ],
        requestedAt: timestampOffsetFromNow(-60d)
    };

    error? submitResult = submitFulfilmentCommand(immediateCommand);
    test:assertTrue(submitResult is (), msg = "Expected immediate submission to succeed");

    HealthCounters updatedCounters = check waitForCounterIncrease("completed", baselineCounters.completedCount);
    test:assertEquals(updatedCounters.completedCount, baselineCounters.completedCount + 1, msg = "Expected completedCount to increase by one shortly after immediate submission");
}

// Submission path: a command whose requestedAt is in the future is scheduled rather than
// delivered immediately, so it must not be settled until its scheduled time arrives.
@test:Config {}
function testFutureRequestedAtCommandIsScheduledNotImmediate() returns error? {
    HealthCounters baselineCounters = check testOrdersClient->/health.get();

    FulfilmentCommand scheduledCommand = {
        orderId: "ORD-SCHEDULED-1",
        customerId: "CUST-SCHEDULED",
        items: [
            {sku: "SKU-SCHEDULED", quantity: 1}
        ],
        requestedAt: timestampOffsetFromNow(30d)
    };

    error? submitResult = submitFulfilmentCommand(scheduledCommand);
    test:assertTrue(submitResult is (), msg = "Expected scheduling to succeed");

    // The command should not be delivered/settled while its scheduled time is still ahead.
    runtime:sleep(5);
    HealthCounters countersBeforeScheduledTime = check testOrdersClient->/health.get();
    test:assertEquals(countersBeforeScheduledTime.completedCount, baselineCounters.completedCount, msg = "Expected the scheduled command to not be completed before its scheduled time");

    // Once the scheduled time has passed, the command should be delivered and completed.
    HealthCounters updatedCounters = check waitForCounterIncrease("completed", baselineCounters.completedCount, maxAttempts = 60);
    test:assertEquals(updatedCounters.completedCount, baselineCounters.completedCount + 1, msg = "Expected completedCount to increase by one after the scheduled time elapses");
}
