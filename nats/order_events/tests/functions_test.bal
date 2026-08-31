import ballerina/test;

// anydataToOrderEvent should correctly bind both raw JSON bytes (as delivered by the
// JetStream service) and an already-typed anydata value to an OrderEvent record, and
// should fail for content that cannot be bound.

@test:Config {}
function testAnydataToOrderEventBindsJsonBytes() returns error? {
    OrderEvent orderEvent = {
        orderId: "order-3001",
        customerId: "customer-801",
        totalAmount: 59.5,
        currency: "USD",
        createdAt: "2026-08-31T00:00:00Z"
    };
    byte[] content = orderEvent.toJsonString().toBytes();

    OrderEvent result = check anydataToOrderEvent(content);

    test:assertEquals(result, orderEvent, msg = "Expected the decoded order event to match the original");
}

@test:Config {}
function testAnydataToOrderEventBindsTypedValue() returns error? {
    OrderEvent orderEvent = {
        orderId: "order-3002",
        customerId: "customer-802",
        totalAmount: 12.25,
        currency: "EUR",
        createdAt: "2026-08-31T01:00:00Z"
    };

    OrderEvent result = check anydataToOrderEvent(orderEvent);

    test:assertEquals(result, orderEvent, msg = "Expected the typed order event to be returned as-is");
}

@test:Config {}
function testAnydataToOrderEventFailsForMalformedBytes() {
    byte[] content = "not valid json".toBytes();

    OrderEvent|error result = anydataToOrderEvent(content);

    test:assertTrue(result is error, msg = "Expected malformed content to fail binding");
}

// persistOrder simulates persistence and should succeed for a well-formed order event.

@test:Config {}
function testPersistOrderSucceeds() {
    OrderEvent orderEvent = {
        orderId: "order-3003",
        customerId: "customer-803",
        totalAmount: 100.0,
        currency: "USD",
        createdAt: "2026-08-31T02:00:00Z"
    };

    TransientPersistenceError? result = persistOrder(orderEvent);

    test:assertTrue(result is (), msg = "Expected persistence to succeed for a well-formed order event");
}
