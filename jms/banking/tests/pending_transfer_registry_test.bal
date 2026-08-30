import ballerina/test;

@test:Config {}
function testRegisterCreatesPendingTransfer() {
    PendingTransferRegistry registry = new;
    registry.register("txn-001");

    PendingTransfer? pendingTransfer = registry.get("txn-001");
    test:assertTrue(pendingTransfer is PendingTransfer, msg = "Expected a pending transfer to be registered");
    if pendingTransfer is PendingTransfer {
        test:assertEquals(pendingTransfer.status, "PENDING");
        test:assertEquals(pendingTransfer.transferId, "txn-001");
    }
}

@test:Config {}
function testCorrelateMatchesPendingTransferAsCompleted() {
    PendingTransferRegistry registry = new;
    registry.register("txn-002");

    boolean correlated = registry.correlate("txn-002", "SUCCESS", "Transfer completed");
    test:assertTrue(correlated, msg = "Expected reply to correlate to the pending transfer");

    PendingTransfer? pendingTransfer = registry.get("txn-002");
    test:assertTrue(pendingTransfer is PendingTransfer);
    if pendingTransfer is PendingTransfer {
        test:assertEquals(pendingTransfer.status, "COMPLETED");
        test:assertEquals(pendingTransfer.coreStatus, "SUCCESS");
        test:assertEquals(pendingTransfer.coreMessage, "Transfer completed");
    }
}

@test:Config {}
function testCorrelateMatchesPendingTransferAsFailed() {
    PendingTransferRegistry registry = new;
    registry.register("txn-003");

    boolean correlated = registry.correlate("txn-003", "REJECTED", "Insufficient funds");
    test:assertTrue(correlated, msg = "Expected reply to correlate to the pending transfer");

    PendingTransfer? pendingTransfer = registry.get("txn-003");
    test:assertTrue(pendingTransfer is PendingTransfer);
    if pendingTransfer is PendingTransfer {
        test:assertEquals(pendingTransfer.status, "FAILED");
        test:assertEquals(pendingTransfer.coreStatus, "REJECTED");
    }
}

@test:Config {}
function testCorrelateReturnsFalseForUnknownTransfer() {
    PendingTransferRegistry registry = new;

    boolean correlated = registry.correlate("unknown-txn", "SUCCESS", ());
    test:assertFalse(correlated, msg = "Expected an unmatched reply not to correlate");

    PendingTransfer? pendingTransfer = registry.get("unknown-txn");
    test:assertTrue(pendingTransfer is (), msg = "Expected no pending transfer to be created for an unmatched reply");
}
