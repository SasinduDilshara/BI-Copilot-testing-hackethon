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
