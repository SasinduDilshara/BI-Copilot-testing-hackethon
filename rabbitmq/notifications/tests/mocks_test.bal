import ballerina/test;
import ballerinax/rabbitmq;

// Replaces the real broker connection for `rabbitmqClient` with a mock so the module doesn't
// need a live broker just to construct that client. Note this does NOT make `bal test` fully
// broker-free: `emailQueueListener`, `pushQueueListener`, and `urgentQueueListener` are genuine
// `listener` declarations bound to the destination consumer services, and listener
// initialization/service attachment always connects to a real broker -- it cannot be
// intercepted via function mocking the way a plain client-init function can. Running the full
// suite (including the RabbitMQ-dependent flows) therefore still requires a reachable broker;
// this mock only keeps the client construction itself out of the way.
@test:Mock {
    functionName: "initRabbitmqClient"
}
function getMockRabbitmqClient() returns rabbitmq:Client|error {
    return test:mock(rabbitmq:Client);
}

// `init()` (module start-up) calls this to declare the broadcast exchange/queue topology on
// `rabbitmqClient`. Runtime stubbing via `test:prepare(...).when(...).thenReturn(...)` cannot
// help here because module `init()` runs before any test lifecycle stubbing takes effect, so
// this function itself is replaced (at compile-time) with a no-op for the test run instead.
@test:Mock {
    functionName: "initNotificationsTopology"
}
function getMockInitNotificationsTopology() returns error? {
    return;
}
