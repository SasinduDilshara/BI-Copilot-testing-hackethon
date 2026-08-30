// Shipment status event received as JSON from the legacy system on SHIPMENT.STATUS.IN.
public type ShipmentStatus record {|
    string shipmentId;
    string carrierCode;
    string status;
    string locationCode;
    string statusAt;
    string exceptionReason?;
|};
