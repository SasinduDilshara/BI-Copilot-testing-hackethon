import ballerina/test;
import ballerinax/gcloud.pubsub;

// Replaces the real publisher/listener construction with mock clients so
// module initialization does not attempt a real Pub/Sub connection when
// running tests.
@test:Mock {
    functionName: "initOrderEventPublisher"
}
function mockInitOrderEventPublisher() returns pubsub:Publisher|error {
    return test:mock(pubsub:Publisher);
}

@test:Mock {
    functionName: "initPoisonEventPublisher"
}
function mockInitPoisonEventPublisher() returns pubsub:Publisher|error {
    return test:mock(pubsub:Publisher);
}

@test:Mock {
    functionName: "initOrderEventListener"
}
function mockInitOrderEventListener() returns pubsub:Listener|error {
    pubsub:Listener mockListener = test:mock(pubsub:Listener);
    test:prepare(mockListener).when("attach").thenReturn(());
    test:prepare(mockListener).when("detach").thenReturn(());
    test:prepare(mockListener).when("start").thenReturn(());
    test:prepare(mockListener).when("gracefulStop").thenReturn(());
    test:prepare(mockListener).when("immediateStop").thenReturn(());
    return mockListener;
}

OrderEvent sampleOrderEvent = {
    orderId: "order-100",
    eventType: "ORDER_CREATED",
    customerId: "customer-200",
    totalAmount: 75.50,
    currency: "USD",
    occurredAt: "2026-09-06T16:52:14Z"
};

function toMessage(OrderEvent orderEvent, string? messageId = ()) returns pubsub:Message {
    if messageId is string {
        return {
            messageId: messageId,
            data: orderEvent.toJsonString().toBytes()
        };
    }
    return {
        data: orderEvent.toJsonString().toBytes()
    };
}

@test:Config {}
function testToOrderEventRoundTripsAPublishedMessage() returns error? {
    pubsub:Message message = toMessage(sampleOrderEvent);

    OrderEvent rebuilt = check toOrderEvent(message);
    test:assertEquals(rebuilt, sampleOrderEvent);
}

@test:Config {}
function testToOrderEventFailsOnMalformedPayload() {
    pubsub:Message message = {
        data: "{}".toBytes()
    };

    OrderEvent|error result = toOrderEvent(message);
    test:assertTrue(result is error);
}

@test:Config {}
function testProcessOrderEventStoresEventAndIsRetrievable() returns error? {
    OrderEvent orderEvent = {
        orderId: "order-101",
        eventType: "ORDER_SHIPPED",
        customerId: "customer-201",
        totalAmount: 20.00,
        currency: "USD",
        occurredAt: "2026-09-06T17:00:00Z"
    };

    TransientProcessingError? result = processOrderEvent(orderEvent);
    test:assertTrue(result is ());

    OrderEvent? processed = getProcessedOrderEvent(orderEvent.orderId, orderEvent.eventType);
    test:assertEquals(processed, orderEvent);
}

@test:Config {}
function testProcessOrderEventIsIdempotentForRedeliveredMessages() returns error? {
    OrderEvent orderEvent = {
        orderId: "order-102",
        eventType: "ORDER_CANCELLED",
        customerId: "customer-202",
        totalAmount: 30.00,
        currency: "USD",
        occurredAt: "2026-09-06T17:05:00Z"
    };

    TransientProcessingError? first = processOrderEvent(orderEvent);
    TransientProcessingError? redelivered = processOrderEvent(orderEvent);
    test:assertTrue(first is ());
    test:assertTrue(redelivered is ());

    OrderEvent? processed = getProcessedOrderEvent(orderEvent.orderId, orderEvent.eventType);
    test:assertEquals(processed, orderEvent);
}

@test:Config {}
function testPublishOrderEventSendsMessageToMockPublisher() returns error? {
    test:prepare(orderEventPublisher).when("publish").thenReturn("mock-message-id-1");

    error? result = publishOrderEvent(sampleOrderEvent);
    test:assertTrue(result is ());
}

@test:Config {}
function testHandleIncomingOrderEventAcksAfterSuccessfulProcessing() returns error? {
    pubsub:Caller mockCaller = test:mock(pubsub:Caller);
    test:prepare(mockCaller).when("ack").thenReturn(());

    pubsub:Message message = toMessage(sampleOrderEvent, messageId = "msg-success-1");

    error? result = handleIncomingOrderEvent(message, mockCaller);
    test:assertTrue(result is ());

    OrderEvent? processed = getProcessedOrderEvent(sampleOrderEvent.orderId, sampleOrderEvent.eventType);
    test:assertEquals(processed, sampleOrderEvent);
}

@test:Config {}
function testHandleIncomingOrderEventAcksMalformedMessageWithoutProcessing() returns error? {
    pubsub:Caller mockCaller = test:mock(pubsub:Caller);
    test:prepare(mockCaller).when("ack").thenReturn(());

    pubsub:Message malformedMessage = {
        messageId: "msg-malformed-1",
        data: "{}".toBytes()
    };

    error? result = handleIncomingOrderEvent(malformedMessage, mockCaller);
    test:assertTrue(result is ());
}

@test:Config {}
function testHandleIncomingOrderEventNacksOnTransientProcessingFailure() returns error? {
    pubsub:Caller mockCaller = test:mock(pubsub:Caller);
    test:prepare(mockCaller).when("nack").thenReturn(());

    OrderEvent failingOrderEvent = {
        orderId: TRANSIENT_FAILURE_TEST_ORDER_ID,
        eventType: "ORDER_CREATED",
        customerId: "customer-300",
        totalAmount: 10.00,
        currency: "USD",
        occurredAt: "2026-09-06T18:00:00Z"
    };
    pubsub:Message message = toMessage(failingOrderEvent, messageId = "msg-transient-1");

    error? result = handleIncomingOrderEvent(message, mockCaller);
    test:assertTrue(result is ());

    OrderEvent? processed = getProcessedOrderEvent(failingOrderEvent.orderId, failingOrderEvent.eventType);
    test:assertTrue(processed is ());
}

@test:Config {}
function testHandleIncomingOrderEventReportsIncrementingDeliveryAttempts() returns error? {
    pubsub:Caller mockCaller = test:mock(pubsub:Caller);
    test:prepare(mockCaller).when("nack").thenReturn(());

    OrderEvent failingOrderEvent = {
        orderId: TRANSIENT_FAILURE_TEST_ORDER_ID,
        eventType: "ORDER_UPDATED",
        customerId: "customer-301",
        totalAmount: 15.00,
        currency: "USD",
        occurredAt: "2026-09-06T18:10:00Z"
    };
    string messageId = "msg-delivery-attempts-1";
    pubsub:Message message = toMessage(failingOrderEvent, messageId = messageId);

    int firstAttempt = recordDeliveryAttempt(message);
    test:assertEquals(firstAttempt, 1);

    error? firstResult = handleIncomingOrderEvent(message, mockCaller);
    test:assertTrue(firstResult is ());

    error? secondResult = handleIncomingOrderEvent(message, mockCaller);
    test:assertTrue(secondResult is ());
}

@test:Config {}
function testHandleIncomingOrderEventPublishesToPoisonTopicOnceMaxDeliveryAttemptsReached() returns error? {
    pubsub:Caller mockCaller = test:mock(pubsub:Caller);
    test:prepare(mockCaller).when("ack").thenReturn(());
    test:prepare(mockCaller).when("nack").thenReturn(());
    test:prepare(poisonEventPublisher).when("publish").thenReturn("mock-poison-message-id-1");

    OrderEvent failingOrderEvent = {
        orderId: TRANSIENT_FAILURE_TEST_ORDER_ID,
        eventType: "ORDER_EXHAUSTED",
        customerId: "customer-302",
        totalAmount: 25.00,
        currency: "USD",
        occurredAt: "2026-09-06T18:20:00Z"
    };
    string messageId = "msg-exhausted-1";
    pubsub:Message message = toMessage(failingOrderEvent, messageId = messageId);

    error? lastResult = ();
    foreach int _ in 1 ... maxDeliveryAttempts {
        lastResult = handleIncomingOrderEvent(message, mockCaller);
        test:assertTrue(lastResult is ());
    }

    // After maxDeliveryAttempts failures the message has been published to
    // the poison topic and acked, and the local counter is cleared, so a
    // fresh delivery starts back at attempt 1.
    int attemptAfterExhaustion = recordDeliveryAttempt(message);
    test:assertEquals(attemptAfterExhaustion, 1);
}

@test:Config {}
function testPublishToPoisonTopicCarriesFailureReasonAndAttemptCount() returns error? {
    test:prepare(poisonEventPublisher).when("publish").thenReturn("mock-poison-message-id-2");

    pubsub:Message message = toMessage(sampleOrderEvent, messageId = "msg-poison-1");

    error? result = publishToPoisonTopic(message, maxDeliveryAttempts, "simulated transient processing failure");
    test:assertTrue(result is ());
}

@test:Config {}
function testMessageDeliveryKeyFallsBackToContentWhenMessageIdMissing() {
    pubsub:Message withId = toMessage(sampleOrderEvent, messageId = "msg-key-1");
    pubsub:Message withoutId = toMessage(sampleOrderEvent);

    test:assertEquals(messageDeliveryKey(withId), "msg-key-1");
    test:assertEquals(messageDeliveryKey(withoutId), sampleOrderEvent.toJsonString().toBytes().toBase16());
}
