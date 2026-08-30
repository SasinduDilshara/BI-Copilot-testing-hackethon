import ballerina/test;
import ballerinax/rabbitmq;

// Replaces the real broker connection for `rabbitmqClient` with a mock so the module doesn't
// need a live broker just to construct that client. Note this does NOT make `bal test` fully
// broker-free: `inventoryQueueListener` is a genuine `listener` declaration bound to the
// inventory responder service, and listener initialization/service attachment always connects
// to a real broker — it cannot be intercepted via function mocking the way a plain client-init
// function can. Running the full suite (including the RabbitMQ-dependent flows) therefore still
// requires a reachable broker; this mock only keeps the client construction itself out of the way.
@test:Mock {
    functionName: "initRabbitmqClient"
}
function getMockRabbitmqClient() returns rabbitmq:Client|error {
    return test:mock(rabbitmq:Client);
}
