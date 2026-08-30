// Binds a JSON payload received from the legacy system into a ShipmentStatus record.
function parseShipmentStatus(string jsonPayload) returns ShipmentStatus|error {
    return jsonPayload.fromJsonStringWithType(ShipmentStatus);
}

// Converts a shipment status into the map content used for the SHIPMENT.STATUS.OUT /
// SHIPMENT.EXCEPTIONS map messages.
function toShipmentStatusContent(ShipmentStatus shipmentStatus) returns map<anydata> => {
    shipmentId: shipmentStatus.shipmentId,
    carrierCode: shipmentStatus.carrierCode,
    status: shipmentStatus.status,
    locationCode: shipmentStatus.locationCode,
    statusAt: shipmentStatus.statusAt,
    exceptionReason: shipmentStatus?.exceptionReason
};

// Resolves the destination queue name for a shipment status event based on its carrier code,
// falling back to the given default queue when the carrier is not present in the routing map.
function resolveCarrierQueue(string carrierCode, map<string> carrierQueues, string defaultQueue) returns string {
    return carrierQueues[carrierCode] ?: defaultQueue;
}
