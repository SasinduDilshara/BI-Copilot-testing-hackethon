import ballerina/websocket;

// In-memory registry of connected dashboard callers, keyed by connection ID.
// Dashboard clients subscribe to every order update broadcast, regardless of order ID.
isolated map<websocket:Caller> dashboardSubscribers = {};

// Registers a dashboard caller so it receives every subsequent order update broadcast.
isolated function addDashboardSubscriber(websocket:Caller caller) {
    lock {
        dashboardSubscribers[caller.getConnectionId()] = caller;
    }
}

// Removes a dashboard caller from the broadcast registry, e.g. on disconnect.
isolated function removeDashboardSubscriber(websocket:Caller caller) {
    lock {
        _ = dashboardSubscribers.removeIfHasKey(caller.getConnectionId());
    }
}

// Broadcasts a single order update to every currently connected dashboard caller.
// Any subscriber that fails to receive the update (e.g. a stale connection) is dropped.
isolated function broadcastToDashboards(readonly & OrderUpdate orderUpdate) {
    lock {
        foreach string connectionId in dashboardSubscribers.keys() {
            websocket:Caller subscriber = dashboardSubscribers.get(connectionId);
            websocket:Error? writeResult = subscriber->writeMessage(orderUpdate);
            if writeResult is websocket:Error {
                _ = dashboardSubscribers.removeIfHasKey(connectionId);
            }
        }
    }
}

// In-memory store of known orders that can be tracked.
// Populated with sample data to simulate an existing orders backend.
isolated map<Order> ordersById = {
    "ORD-1001": {
        orderId: "ORD-1001",
        status: "PREPARING",
        courierLocation: {latitude: 6.9271, longitude: 79.8612},
        estimatedArrival: "2026-08-31T09:10:00Z"
    },
    "ORD-1002": {
        orderId: "ORD-1002",
        status: "OUT_FOR_DELIVERY",
        courierLocation: {latitude: 6.9147, longitude: 79.8728},
        estimatedArrival: "2026-08-31T08:55:00Z"
    },
    "ORD-1003": {
        orderId: "ORD-1003",
        status: "CONFIRMED",
        courierLocation: {latitude: 6.9022, longitude: 79.8607},
        estimatedArrival: "2026-08-31T09:30:00Z"
    }
};

// Tracks whether a given order ID is a known, trackable order.
isolated function isKnownOrder(string orderId) returns boolean {
    lock {
        return ordersById.hasKey(orderId);
    }
}

// Retrieves the current snapshot of an order, if present.
isolated function getOrder(string orderId) returns Order? {
    lock {
        Order? found = ordersById[orderId];
        return found.clone();
    }
}

// Applies the next simulated status transition for the given order and returns the updated snapshot.
isolated function advanceOrder(string orderId) returns Order? {
    lock {
        Order? current = ordersById[orderId];
        if current is () {
            return ();
        }
        Order updated = current.clone();
        string nextStatus = getNextStatus(updated.status);
        updated.status = nextStatus;
        updated.courierLocation.latitude = updated.courierLocation.latitude + 0.001d;
        updated.courierLocation.longitude = updated.courierLocation.longitude + 0.001d;
        ordersById[orderId] = updated;
        return updated.clone();
    }
}

// Determines the next status in the simulated delivery lifecycle.
isolated function getNextStatus(string currentStatus) returns string {
    if currentStatus == "CONFIRMED" {
        return "PREPARING";
    }
    if currentStatus == "PREPARING" {
        return "OUT_FOR_DELIVERY";
    }
    if currentStatus == "OUT_FOR_DELIVERY" {
        return "DELIVERED";
    }
    return "DELIVERED";
}
