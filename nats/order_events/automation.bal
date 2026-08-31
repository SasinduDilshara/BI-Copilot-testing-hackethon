import ballerina/time;

public function main() returns error? {
    check initOrdersStream();

    OrderEvent orderEvent = {
        orderId: "order-2001",
        customerId: "customer-701",
        totalAmount: 149.99,
        currency: "USD",
        createdAt: time:utcToString(time:utcNow())
    };
    check publishOrderCreatedEvent(orderEvent);
}
