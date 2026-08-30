import ballerina/test;

function sampleDeadLetterMessage(string claimId) returns DeadLetterMessage => {
    claimId,
    routingKey: "claim.auto.high",
    retryCount: 3,
    failureReason: "Invalid claim amount",
    claim: {
        claimId,
        policyNumber: "POL-99",
        claimType: "auto",
        claimAmount: 0d,
        incidentDate: "2026-08-01",
        priority: "high"
    }
};

@test:Config {}
function testAddAndListDeadLetterMessage() {
    clearDeadLetterMessages();
    DeadLetterMessage deadLetterMessage = sampleDeadLetterMessage("CLM-DL-1");
    addDeadLetterMessage(deadLetterMessage);

    DeadLetterMessage[] messages = listDeadLetterMessages();
    test:assertEquals(messages.length(), 1, msg = "There should be exactly one dead-lettered message");
    test:assertEquals(messages[0].claimId, "CLM-DL-1", msg = "The listed message should match the added claim");
    clearDeadLetterMessages();
}

@test:Config {}
function testRemoveDeadLetterMessage() {
    clearDeadLetterMessages();
    DeadLetterMessage deadLetterMessage = sampleDeadLetterMessage("CLM-DL-2");
    addDeadLetterMessage(deadLetterMessage);

    DeadLetterMessage? removedMessage = removeDeadLetterMessage("CLM-DL-2");
    test:assertTrue(removedMessage is DeadLetterMessage, msg = "The message should be found and removed");
    if removedMessage is DeadLetterMessage {
        test:assertEquals(removedMessage.claimId, "CLM-DL-2", msg = "The removed message should match the claim ID");
    }

    DeadLetterMessage[] messages = listDeadLetterMessages();
    test:assertEquals(messages.length(), 0, msg = "The store should be empty after removal");
}

@test:Config {}
function testRemoveMissingDeadLetterMessageReturnsNil() {
    clearDeadLetterMessages();
    DeadLetterMessage? removedMessage = removeDeadLetterMessage("CLM-DOES-NOT-EXIST");
    test:assertTrue(removedMessage is (), msg = "Removing a missing claim ID should return nil");
}

@test:Config {}
function testClearDeadLetterMessages() {
    clearDeadLetterMessages();
    addDeadLetterMessage(sampleDeadLetterMessage("CLM-DL-3"));
    addDeadLetterMessage(sampleDeadLetterMessage("CLM-DL-4"));

    clearDeadLetterMessages();
    DeadLetterMessage[] messages = listDeadLetterMessages();
    test:assertEquals(messages.length(), 0, msg = "The store should be empty after clearing");
}
