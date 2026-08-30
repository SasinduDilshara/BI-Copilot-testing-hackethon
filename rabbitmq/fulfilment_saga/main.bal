import ballerina/http;

function init() returns error? {
    check initFulfilmentTopology();
}

service /fulfilment on new http:Listener(httpListenerPort) {

    # Accepts an order fulfilment request and starts the fulfilment saga asynchronously: the
    # inventory reservation request is published immediately and this resource returns without
    # waiting for the reply. The saga is advanced in the background by the reply consumer on
    # `fulfilment.replies`; poll the saga status endpoint for the outcome.
    #
    # + fulfilmentRequest - the order fulfilment request payload
    # + return - 202 Accepted once the reservation request has been published, or a 500 if it
    # could not be published
    resource function post orders(FulfilmentRequest fulfilmentRequest)
            returns http:Accepted|http:InternalServerError {
        error? startResult = startFulfilmentSaga(fulfilmentRequest);

        if startResult is error {
            ErrorMessage errorMessage = {message: "Failed to start fulfilment saga: " + startResult.message()};
            return <http:InternalServerError>{body: errorMessage};
        }

        FulfilmentAccepted fulfilmentAccepted = {
            orderId: fulfilmentRequest.orderId,
            statusUrl: string `/fulfilment/orders/${fulfilmentRequest.orderId}/saga`
        };
        return <http:Accepted>{body: fulfilmentAccepted};
    }

    # Reports the current saga state (progress and any compensating actions taken) for an order.
    #
    # + orderId - the order to look up
    # + return - 200 OK with the saga state, or 404 if no saga has been started for this order
    resource function get orders/[string orderId]/saga() returns SagaState|http:NotFound {
        SagaState? sagaState = getSagaState(orderId);
        if sagaState is () {
            ErrorMessage errorMessage = {message: string `No saga found for order ${orderId}`};
            return <http:NotFound>{body: errorMessage};
        }
        return sagaState;
    }
}
