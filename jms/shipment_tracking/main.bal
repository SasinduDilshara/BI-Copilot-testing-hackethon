import ballerina/log;
import ballerinax/java.jms;

service "shipment-status-consumer" on shipmentStatusListener {

    // Binds the JSON payload into a ShipmentStatus record. Messages that fail binding are
    // forwarded to SHIPMENT.STATUS.DLQ with the error category attached as a property, then
    // acknowledged so they do not redeliver forever.
    remote function onMessage(jms:Message message, jms:Caller caller) returns error? {
        if message !is jms:TextMessage {
            log:printWarn("Received non-text shipment status message, routing to DLQ");
            check forwardToDlq(message, "NON_TEXT_MESSAGE", error("Message is not a text message"));
            check caller->acknowledge(message);
            return;
        }

        string jsonPayload = message.content;
        ShipmentStatus|error shipmentStatus = parseShipmentStatus(jsonPayload);
        if shipmentStatus is error {
            log:printWarn("Failed to bind shipment status JSON, routing to DLQ", 'error = shipmentStatus);
            check forwardToDlq(message, "JSON_BINDING_FAILURE", shipmentStatus);
            check caller->acknowledge(message);
            return;
        }

        processShipmentStatus(shipmentStatus);
        check publishShipmentStatus(shipmentStatus);
        check caller->acknowledge(message);
    }
}

// Handles a successfully parsed shipment status event. Replace with the actual downstream
// processing logic.
function processShipmentStatus(ShipmentStatus shipmentStatus) {
    log:printInfo("Shipment status processed",
            shipmentId = shipmentStatus.shipmentId,
            carrierCode = shipmentStatus.carrierCode,
            status = shipmentStatus.status,
            locationCode = shipmentStatus.locationCode);
}
