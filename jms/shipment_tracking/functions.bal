import ballerinax/java.jms;

// Forwards a message that failed JSON binding to SHIPMENT.STATUS.DLQ, attaching the error
// category and message as properties so downstream consumers can inspect the failure reason
// without having to re-parse the payload.
function forwardToDlq(jms:Message originalMessage, string errorCategory, error bindingError) returns error? {
    jms:TextMessage dlqMessage = {
        content: originalMessage is jms:TextMessage ? originalMessage.content : "",
        properties: {
            errorCategory,
            errorMessage: bindingError.message()
        }
    };
    check shipmentStatusDlqProducer->send(dlqMessage);
}

// Publishes a successfully parsed shipment status event as a map message, routing it by carrier
// to either an exception queue or a regular status-out queue. Both carrier and status are set as
// message properties so downstream consumers can filter using JMS message selectors.
function publishShipmentStatus(ShipmentStatus shipmentStatus) returns error? {
    map<anydata> content = toShipmentStatusContent(shipmentStatus);
    string? exceptionReason = shipmentStatus?.exceptionReason;
    string carrierCode = shipmentStatus.carrierCode;

    if exceptionReason is string {
        string destinationQueue = resolveCarrierQueue(carrierCode, carrierExceptionQueues, defaultShipmentExceptionQueue);
        jms:MapMessage exceptionMessage = {
            content,
            priority: exceptionPriority,
            expiration: exceptionTtlMillis,
            properties: {
                carrier: carrierCode,
                status: shipmentStatus.status
            }
        };
        check shipmentStatusRoutedProducer->sendTo({'type: jms:QUEUE, name: destinationQueue}, exceptionMessage);
        return;
    }

    string destinationQueue = resolveCarrierQueue(carrierCode, carrierStatusOutQueues, defaultShipmentStatusOutQueue);
    jms:MapMessage acceptedMessage = {
        content,
        properties: {
            carrier: carrierCode,
            status: shipmentStatus.status
        }
    };
    check shipmentStatusRoutedProducer->sendTo({'type: jms:QUEUE, name: destinationQueue}, acceptedMessage);
}
