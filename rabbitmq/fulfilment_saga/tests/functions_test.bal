import ballerina/test;

function sampleReservationRequest(string orderId, string sku = "SKU-1", int quantity = 2) returns ReservationRequest => {
    orderId,
    warehouseId: "WH-1",
    items: [{sku, quantity}]
};

function sampleFulfilmentRequest(string orderId, string warehouseId = "WH-1") returns FulfilmentRequest => {
    orderId,
    warehouseId,
    items: [{sku: "SKU-1", quantity: 2}],
    shippingMethod: "STANDARD"
};

@test:Config {}
function testCheckStockSucceedsForInStockItems() returns error? {
    ReservationRequest reservationRequest = sampleReservationRequest("ORD-1");
    check checkStock(reservationRequest);
}

@test:Config {}
function testCheckStockFailsForOutOfStockSku() {
    ReservationRequest reservationRequest = sampleReservationRequest("ORD-2", sku = "OUT-OF-STOCK");
    error? stockCheckResult = checkStock(reservationRequest);
    test:assertTrue(stockCheckResult is error, msg = "Stock check should fail for the OUT-OF-STOCK sentinel SKU");
    if stockCheckResult is error {
        test:assertEquals(stockCheckResult.message(), "Insufficient stock for SKU OUT-OF-STOCK (order ORD-2)",
                msg = "Error message should describe the shortfall");
    }
}

@test:Config {}
function testCheckStockFailsForNonPositiveQuantity() {
    ReservationRequest reservationRequest = sampleReservationRequest("ORD-3", quantity = 0);
    error? stockCheckResult = checkStock(reservationRequest);
    test:assertTrue(stockCheckResult is error, msg = "Stock check should fail for a non-positive quantity");
}

@test:Config {}
function testChargePaymentSucceedsForNormalOrder() returns error? {
    FulfilmentRequest fulfilmentRequest = sampleFulfilmentRequest("ORD-4");
    check chargePayment(fulfilmentRequest);
}

@test:Config {}
function testChargePaymentFailsForPaymentFailSentinel() {
    FulfilmentRequest fulfilmentRequest = sampleFulfilmentRequest("ORD-5", warehouseId = "PAYMENT-FAIL");
    error? paymentResult = chargePayment(fulfilmentRequest);
    test:assertTrue(paymentResult is error, msg = "Payment should fail for the PAYMENT-FAIL sentinel warehouse ID");
    if paymentResult is error {
        test:assertEquals(paymentResult.message(), "Payment charge failed for order ORD-5",
                msg = "Error message should describe the payment failure");
    }
}

@test:Config {}
function testRegisterAndTakePendingReservation() {
    FulfilmentRequest fulfilmentRequest = sampleFulfilmentRequest("ORD-6");
    registerPendingReservation("CORR-1", fulfilmentRequest);

    FulfilmentRequest? takenRequest = takePendingReservation("CORR-1");
    test:assertTrue(takenRequest is FulfilmentRequest, msg = "The registered request should be found");
    if takenRequest is FulfilmentRequest {
        test:assertEquals(takenRequest.orderId, "ORD-6", msg = "The taken request should match the registered order");
    }

    FulfilmentRequest? takenAgain = takePendingReservation("CORR-1");
    test:assertTrue(takenAgain is (), msg = "Taking the same correlation ID twice should return nil");
}

@test:Config {}
function testTakePendingReservationReturnsNilForUnknownCorrelationId() {
    FulfilmentRequest? takenRequest = takePendingReservation("CORR-DOES-NOT-EXIST");
    test:assertTrue(takenRequest is (), msg = "Taking an unregistered correlation ID should return nil");
}

@test:Config {}
function testHandleReservationReplySucceedsAndCompletesSaga() {
    FulfilmentRequest fulfilmentRequest = sampleFulfilmentRequest("ORD-8");
    _ = startSaga("ORD-8");
    registerPendingReservation("CORR-2", fulfilmentRequest);

    handleReservationReply("CORR-2", {orderId: "ORD-8", reserved: true});

    SagaState? sagaState = getSagaState("ORD-8");
    test:assertTrue(sagaState is SagaState, msg = "The saga should exist after handling the reply");
    if sagaState is SagaState {
        test:assertEquals(sagaState.status, SAGA_COMPLETED, msg = "Saga should complete on a successful reservation and payment");
        test:assertEquals(sagaState.completedSteps, ["reserve-inventory", "charge-payment"],
                msg = "Both forward steps should be recorded");
    }
}

@test:Config {}
function testHandleReservationReplyDeclinedFailsSaga() {
    FulfilmentRequest fulfilmentRequest = sampleFulfilmentRequest("ORD-9");
    _ = startSaga("ORD-9");
    registerPendingReservation("CORR-3", fulfilmentRequest);

    handleReservationReply("CORR-3", {orderId: "ORD-9", reserved: false, message: "No stock"});

    SagaState? sagaState = getSagaState("ORD-9");
    test:assertTrue(sagaState is SagaState, msg = "The saga should exist after handling the reply");
    if sagaState is SagaState {
        test:assertEquals(sagaState.status, SAGA_FAILED, msg = "Saga should fail when the reservation is declined");
        test:assertEquals(sagaState.failureReason, "No stock", msg = "Failure reason should come from the reply message");
    }
}

@test:Config {}
function testHandleReservationReplyPaymentFailureReleasesInventory() {
    FulfilmentRequest fulfilmentRequest = sampleFulfilmentRequest("ORD-10", warehouseId = "PAYMENT-FAIL");
    _ = startSaga("ORD-10");
    registerPendingReservation("CORR-4", fulfilmentRequest);

    handleReservationReply("CORR-4", {orderId: "ORD-10", reserved: true});

    SagaState? sagaState = getSagaState("ORD-10");
    test:assertTrue(sagaState is SagaState, msg = "The saga should exist after handling the reply");
    if sagaState is SagaState {
        test:assertEquals(sagaState.status, SAGA_FAILED, msg = "Saga should fail when payment charging fails");
        test:assertEquals(sagaState.compensatingSteps, ["release-inventory"],
                msg = "Inventory should be released as the compensating action");
    }
}
