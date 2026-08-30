import ballerina/log;
import ballerinax/rabbitmq;

# Publishes a reservation request for the given fulfilment request to the inventory service.
# The reply is expected asynchronously on the shared `fulfilment.replies` queue, correlated by
# `correlationId`; this function does not wait for it. The saga is advanced by the reply
# consumer once the reservation response arrives.
#
# + fulfilmentRequest - the fulfilment request to reserve inventory for
# + return - the correlation ID assigned to this reservation request, or an error if the
# request could not be published
function publishInventoryReservation(FulfilmentRequest fulfilmentRequest) returns string|error {
    string correlationId = fulfilmentRequest.orderId;

    ReservationRequest reservationRequest = {
        orderId: fulfilmentRequest.orderId,
        warehouseId: fulfilmentRequest.warehouseId,
        items: fulfilmentRequest.items
    };
    rabbitmq:BasicProperties properties = {
        replyTo: FULFILMENT_REPLIES_QUEUE,
        correlationId: correlationId,
        contentType: "application/json"
    };
    rabbitmq:AnydataMessage reservationMessage = {
        content: reservationRequest,
        routingKey: INVENTORY_RESERVE_QUEUE,
        properties: properties
    };
    check rabbitmqClient->publishMessage(reservationMessage);
    return correlationId;
}

# Simulates charging payment for an order. The sentinel warehouse ID `PAYMENT-FAIL` always
# fails, making the failure/compensation path easy to exercise from tests.
#
# + fulfilmentRequest - the fulfilment request being paid for
# + return - () on success, or an error describing why the charge failed
isolated function chargePayment(FulfilmentRequest fulfilmentRequest) returns error? {
    if fulfilmentRequest.warehouseId == "PAYMENT-FAIL" {
        return error(string `Payment charge failed for order ${fulfilmentRequest.orderId}`);
    }
}

# Simulates releasing a previously reserved inventory hold. This is the compensating action for
# a successful inventory reservation, run when a later saga step (payment) fails.
#
# + fulfilmentRequest - the fulfilment request whose inventory reservation should be released
isolated function releaseInventory(FulfilmentRequest fulfilmentRequest) {
    log:printInfo(string `Releasing inventory reservation for order ${fulfilmentRequest.orderId}`);
}

# Starts the fulfilment saga for a single request: records the initial saga state, registers the
# request as pending a reservation reply, and publishes the reservation request. Returns
# immediately after publishing; the saga is advanced asynchronously by the reply consumer on
# `fulfilment.replies`.
#
# + fulfilmentRequest - the order fulfilment request driving the saga
# + return - () once the reservation request has been published, or an error if publishing failed
function startFulfilmentSaga(FulfilmentRequest fulfilmentRequest) returns error? {
    string orderId = fulfilmentRequest.orderId;
    _ = startSaga(orderId);

    string|error correlationId = publishInventoryReservation(fulfilmentRequest);
    if correlationId is error {
        failSaga(orderId, correlationId.message());
        return correlationId;
    }

    registerPendingReservation(correlationId, fulfilmentRequest);
    recordSagaStep(orderId, SAGA_AWAITING_RESERVATION, "request-inventory-reservation");
}

# Handles a reservation reply consumed from `fulfilment.replies`: looks up the saga the reply
# belongs to (by correlation ID), then either advances it (charging payment on a successful
# reservation) or fails it (declined reservation). Payment failure triggers the compensating
# inventory release.
#
# + correlationId - the correlation ID the reply arrived with, linking it back to its saga
# + reservationResponse - the decoded reservation response
function handleReservationReply(string correlationId, ReservationResponse reservationResponse) {
    FulfilmentRequest? fulfilmentRequest = takePendingReservation(correlationId);
    if fulfilmentRequest is () {
        log:printError(string `No pending saga found for correlation ID ${correlationId}; ignoring reply.`);
        return;
    }

    string orderId = fulfilmentRequest.orderId;
    if !reservationResponse.reserved {
        string reservationFailureReason = reservationResponse?.message ?: "Inventory reservation was declined";
        failSaga(orderId, reservationFailureReason);
        return;
    }
    recordSagaStep(orderId, SAGA_INVENTORY_RESERVED, "reserve-inventory");

    error? paymentResult = chargePayment(fulfilmentRequest);
    if paymentResult is error {
        releaseInventory(fulfilmentRequest);
        recordCompensation(orderId, "release-inventory");
        failSaga(orderId, paymentResult.message());
        return;
    }
    recordSagaStep(orderId, SAGA_PAYMENT_CHARGED, "charge-payment");
    completeSaga(orderId);
}
