import ballerina/time;

# In-memory store tracking the saga state for each order currently being (or having been)
# fulfilled. Keyed by orderId.
isolated map<SagaState> sagaStore = {};

# In-memory store tracking fulfilment requests awaiting an inventory reservation reply. Keyed by
# the correlation ID the reservation request was published with, so the reply consumer on
# `fulfilment.replies` can look up (and remove) the originating request once its reply arrives.
isolated map<FulfilmentRequest> pendingReservations = {};

# Registers a fulfilment request as pending a reservation reply.
#
# + correlationId - the correlation ID the reservation request was published with
# + fulfilmentRequest - the fulfilment request awaiting a reply
isolated function registerPendingReservation(string correlationId, FulfilmentRequest fulfilmentRequest) {
    lock {
        pendingReservations[correlationId] = fulfilmentRequest.clone();
    }
}

# Removes and returns the fulfilment request pending the given correlation ID, if any. Used by
# the reply consumer to both look up and clear the pending entry in a single step, so a
# duplicate/redelivered reply cannot be processed twice.
#
# + correlationId - the correlation ID the reply arrived with
# + return - the pending fulfilment request, or () if no request is pending for this correlation ID
isolated function takePendingReservation(string correlationId) returns FulfilmentRequest? {
    lock {
        return pendingReservations.removeIfHasKey(correlationId).clone();
    }
}

# Creates and stores the initial (STARTED) saga state for an order.
#
# + orderId - the order the saga is being run for
# + return - the newly created saga state
isolated function startSaga(string orderId) returns SagaState {
    SagaState sagaState = {
        orderId,
        status: SAGA_STARTED,
        completedSteps: [],
        compensatingSteps: [],
        failureReason: (),
        lastUpdated: time:utcToString(time:utcNow())
    };
    lock {
        sagaStore[orderId] = sagaState.clone();
    }
    return sagaState;
}

# Records that a forward saga step completed successfully, updating the saga's status.
#
# + orderId - the order the saga is being run for
# + status - the new status to move the saga to
# + stepName - a human-readable name for the completed step
isolated function recordSagaStep(string orderId, SagaStatus status, string stepName) {
    lock {
        SagaState? currentState = sagaStore[orderId];
        if currentState is SagaState {
            currentState.status = status;
            currentState.completedSteps.push(stepName);
            currentState.lastUpdated = time:utcToString(time:utcNow());
            sagaStore[orderId] = currentState.clone();
        }
    }
}

# Records that a compensating action was performed for a previously completed step.
#
# + orderId - the order the saga is being run for
# + stepName - a human-readable name for the compensating action performed
isolated function recordCompensation(string orderId, string stepName) {
    lock {
        SagaState? currentState = sagaStore[orderId];
        if currentState is SagaState {
            currentState.compensatingSteps.push(stepName);
            currentState.lastUpdated = time:utcToString(time:utcNow());
            sagaStore[orderId] = currentState.clone();
        }
    }
}

# Marks the saga as failed, recording the reason it could not complete.
#
# + orderId - the order the saga is being run for
# + failureReason - a description of why the saga failed
isolated function failSaga(string orderId, string failureReason) {
    lock {
        SagaState? currentState = sagaStore[orderId];
        if currentState is SagaState {
            currentState.status = SAGA_FAILED;
            currentState.failureReason = failureReason;
            currentState.lastUpdated = time:utcToString(time:utcNow());
            sagaStore[orderId] = currentState.clone();
        }
    }
}

# Marks the saga as fully completed.
#
# + orderId - the order the saga is being run for
isolated function completeSaga(string orderId) {
    lock {
        SagaState? currentState = sagaStore[orderId];
        if currentState is SagaState {
            currentState.status = SAGA_COMPLETED;
            currentState.lastUpdated = time:utcToString(time:utcNow());
            sagaStore[orderId] = currentState.clone();
        }
    }
}

# Looks up the current saga state for an order.
#
# + orderId - the order to look up
# + return - the saga state, or () if no saga has been started for this order
isolated function getSagaState(string orderId) returns SagaState? {
    lock {
        SagaState? currentState = sagaStore[orderId];
        return currentState.clone();
    }
}
