import ballerina/test;

// Builds a valid order event used as the baseline for validation tests.
function buildValidOrderEvent() returns OrderEvent => {
    orderId: "ORD-1001",
    customerId: "CUST-501",
    orderAmount: 149.99d,
    currency: "USD",
    itemCount: 3,
    channel: "web",
    customerTier: "GOLD",
    customerEmail: "customer@example.com",
    customerCountry: "US"
};

@test:Config {}
function testValidateOrderEventAcceptsValidPayload() {
    OrderEvent orderEvent = buildValidOrderEvent();
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is (), msg = "A well-formed order event should pass validation");
}

@test:Config {}
function testValidateOrderEventRejectsMissingOrderId() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.orderId = "";
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError, msg = "Missing orderId should fail validation");
    if validationError is InvalidOrderEventError {
        test:assertEquals(validationError.message(), "Order event is missing orderId",
                msg = "Unexpected validation error message for missing orderId");
    }
}

@test:Config {}
function testValidateOrderEventRejectsMissingCustomerId() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.customerId = "  ";
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError, msg = "Missing customerId should fail validation");
}

@test:Config {}
function testValidateOrderEventRejectsNonPositiveOrderAmount() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.orderAmount = 0d;
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError,
            msg = "Non-positive orderAmount should fail validation");
}

@test:Config {}
function testValidateOrderEventRejectsMissingCurrency() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.currency = "";
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError, msg = "Missing currency should fail validation");
}

@test:Config {}
function testValidateOrderEventRejectsNonPositiveItemCount() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.itemCount = 0;
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError,
            msg = "Non-positive itemCount should fail validation");
}

@test:Config {}
function testValidateOrderEventRejectsMissingChannel() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.channel = "";
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError, msg = "Missing channel should fail validation");
}

@test:Config {}
function testValidateOrderEventRejectsMissingCustomerTier() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.customerTier = "";
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError, msg = "Missing customerTier should fail validation");
}

@test:Config {}
function testValidateOrderEventRejectsMissingCustomerEmail() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.customerEmail = "  ";
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError, msg = "Missing customerEmail should fail validation");
}

@test:Config {}
function testValidateOrderEventRejectsMissingCustomerCountry() {
    OrderEvent orderEvent = buildValidOrderEvent();
    orderEvent.customerCountry = "";
    InvalidOrderEventError? validationError = validateOrderEvent(orderEvent);
    test:assertTrue(validationError is InvalidOrderEventError,
            msg = "Missing customerCountry should fail validation");
}

@test:Config {}
function testToEnrichedOrderMapsAllFieldsFromEvent() {
    OrderEvent orderEvent = buildValidOrderEvent();
    EnrichedOrder enrichedOrder = toEnrichedOrder(orderEvent);
    test:assertEquals(enrichedOrder.orderId, orderEvent.orderId, msg = "orderId should be carried over");
    test:assertEquals(enrichedOrder.customerId, orderEvent.customerId, msg = "customerId should be carried over");
    test:assertEquals(enrichedOrder.customerTier, orderEvent.customerTier,
            msg = "customerTier should be carried over");
    test:assertEquals(enrichedOrder.customerEmail, orderEvent.customerEmail,
            msg = "customerEmail should be carried over");
    test:assertEquals(enrichedOrder.customerCountry, orderEvent.customerCountry,
            msg = "customerCountry should be carried over");
}
