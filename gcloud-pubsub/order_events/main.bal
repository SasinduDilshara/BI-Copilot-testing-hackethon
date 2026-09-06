import ballerina/log;

public function main() returns error? {
    OrderEvent orderEvent = {
        orderId: "order-001",
        eventType: "ORDER_CREATED",
        customerId: "customer-100",
        totalAmount: 149.99,
        currency: "USD",
        occurredAt: "2026-09-06T16:47:14Z"
    };

    error? result = publishOrderEvent(orderEvent);
    if result is error {
        log:printError("Failed to publish order event", result);
        return result;
    }
}
