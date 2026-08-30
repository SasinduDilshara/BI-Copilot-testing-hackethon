import ballerina/test;

@test:Config {}
function testStartSagaCreatesInitialState() {
    SagaState sagaState = startSaga("SAGA-ORD-1");
    test:assertEquals(sagaState.orderId, "SAGA-ORD-1", msg = "Saga state should be for the requested order");
    test:assertEquals(sagaState.status, SAGA_STARTED, msg = "A newly started saga should be in STARTED status");
    test:assertEquals(sagaState.completedSteps.length(), 0, msg = "A newly started saga has no completed steps yet");
    test:assertEquals(sagaState.compensatingSteps.length(), 0, msg = "A newly started saga has no compensations yet");

    SagaState? storedState = getSagaState("SAGA-ORD-1");
    test:assertTrue(storedState is SagaState, msg = "The started saga should be retrievable from the store");
}

@test:Config {}
function testRecordSagaStepUpdatesStatusAndSteps() {
    _ = startSaga("SAGA-ORD-2");
    recordSagaStep("SAGA-ORD-2", SAGA_INVENTORY_RESERVED, "reserve-inventory");

    SagaState? sagaState = getSagaState("SAGA-ORD-2");
    test:assertTrue(sagaState is SagaState, msg = "The saga should still exist after recording a step");
    if sagaState is SagaState {
        test:assertEquals(sagaState.status, SAGA_INVENTORY_RESERVED, msg = "Status should move to INVENTORY_RESERVED");
        test:assertEquals(sagaState.completedSteps, ["reserve-inventory"],
                msg = "The completed step should be recorded");
    }
}

@test:Config {}
function testRecordCompensationAppendsCompensatingStep() {
    _ = startSaga("SAGA-ORD-3");
    recordSagaStep("SAGA-ORD-3", SAGA_INVENTORY_RESERVED, "reserve-inventory");
    recordCompensation("SAGA-ORD-3", "release-inventory");

    SagaState? sagaState = getSagaState("SAGA-ORD-3");
    test:assertTrue(sagaState is SagaState, msg = "The saga should still exist after recording a compensation");
    if sagaState is SagaState {
        test:assertEquals(sagaState.compensatingSteps, ["release-inventory"],
                msg = "The compensating step should be recorded");
    }
}

@test:Config {}
function testFailSagaSetsFailedStatusAndReason() {
    _ = startSaga("SAGA-ORD-4");
    failSaga("SAGA-ORD-4", "Payment charge failed for order SAGA-ORD-4");

    SagaState? sagaState = getSagaState("SAGA-ORD-4");
    test:assertTrue(sagaState is SagaState, msg = "The saga should still exist after failing");
    if sagaState is SagaState {
        test:assertEquals(sagaState.status, SAGA_FAILED, msg = "Status should move to FAILED");
        test:assertEquals(sagaState.failureReason, "Payment charge failed for order SAGA-ORD-4",
                msg = "The failure reason should be recorded");
    }
}

@test:Config {}
function testCompleteSagaSetsCompletedStatus() {
    _ = startSaga("SAGA-ORD-5");
    recordSagaStep("SAGA-ORD-5", SAGA_INVENTORY_RESERVED, "reserve-inventory");
    recordSagaStep("SAGA-ORD-5", SAGA_PAYMENT_CHARGED, "charge-payment");
    completeSaga("SAGA-ORD-5");

    SagaState? sagaState = getSagaState("SAGA-ORD-5");
    test:assertTrue(sagaState is SagaState, msg = "The saga should still exist after completing");
    if sagaState is SagaState {
        test:assertEquals(sagaState.status, SAGA_COMPLETED, msg = "Status should move to COMPLETED");
        test:assertEquals(sagaState.completedSteps.length(), 2, msg = "Both forward steps should be recorded");
    }
}

@test:Config {}
function testGetSagaStateReturnsNilForUnknownOrder() {
    SagaState? sagaState = getSagaState("SAGA-ORD-DOES-NOT-EXIST");
    test:assertTrue(sagaState is (), msg = "Looking up an unknown order should return nil");
}
