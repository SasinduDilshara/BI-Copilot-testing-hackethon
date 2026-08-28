import ballerina/http;
import ballerinax/solace;

# Represents the category of a flight operational event.
public enum EventType {
    GATE_CHANGE,
    DELAY,
    CANCELLATION,
    BOARDING,
    DEPARTED,
    ARRIVED
}

# Represents a flight operational event submitted by a client.
#
# + eventId - Unique identifier for the event
# + flightNumber - Flight number associated with the event
# + carrierCode - Carrier (airline) code operating the flight
# + departureAirport - IATA/ICAO code of the departure airport
# + arrivalAirport - IATA/ICAO code of the arrival airport
# + eventType - Category of the operational event
# + scheduledTime - Originally scheduled time for the flight event
# + actualTime - Actual time at which the event occurred
# + delayMinutes - Delay duration in minutes, applicable for delay related events
public type FlightEvent record {|
    string eventId;
    string flightNumber;
    string carrierCode;
    string departureAirport;
    string arrivalAirport;
    EventType eventType;
    string scheduledTime;
    string actualTime;
    int delayMinutes?;
|};

# Represents a successful acknowledgement after publishing a flight event.
#
# + eventId - Unique identifier of the published event
# + topic - Hierarchical Solace topic the event was published to
public type FlightEventAck record {|
    string eventId;
    string topic;
|};

# Represents the response returned when a flight event is accepted for publishing.
public type FlightEventAccepted record {|
    *http:Created;
    FlightEventAck body;
|};

# Represents an error detail payload.
#
# + message - Human readable error description
public type ErrorDetail record {|
    string message;
|};

# Represents the response returned when the request payload is invalid.
public type FlightEventBadRequest record {|
    *http:BadRequest;
    ErrorDetail body;
|};

# Represents the response returned when publishing the event to Solace fails.
public type FlightEventPublishError record {|
    *http:InternalServerError;
    ErrorDetail body;
|};

# Represents a guaranteed message consumed from the disruptions queue, narrowed so that the
# `FlightEvent` payload is data-bound directly instead of being delivered as raw `anydata`.
#
# + payload - The flight event carried by the message
public type DisruptionEventMessage record {|
    *solace:Message;
    FlightEvent payload;
|};

# Represents a retryable failure encountered while processing a disruption event. The message
# should be negatively acknowledged with requeue so that it is redelivered.
public type TransientProcessingError distinct error;

# Represents a non-retryable failure encountered while processing a disruption event. The message
# should be negatively acknowledged without requeue so that it is not redelivered.
public type PermanentProcessingError distinct error;

# Represents a passenger rebooking request submitted by a client.
#
# + passengerId - Unique identifier of the passenger to rebook
# + originalFlightNumber - Flight number the passenger was originally booked on
# + carrierCode - Carrier (airline) code operating the original flight
# + reason - Reason for the rebooking request
public type RebookingRequest record {|
    string passengerId;
    string originalFlightNumber;
    string carrierCode;
    string reason;
|};

# Represents the rebooking response published back to the requester.
#
# + passengerId - Unique identifier of the rebooked passenger
# + originalFlightNumber - Flight number the passenger was originally booked on
# + newFlightNumber - Flight number the passenger has been rebooked onto
# + status - Outcome of the rebooking attempt
public type RebookingResponse record {|
    string passengerId;
    string originalFlightNumber;
    string newFlightNumber;
    string status;
|};

# Represents a rebooking request message consumed by the responder, narrowed so that the
# `RebookingRequest` payload is data-bound directly instead of being delivered as raw `anydata`.
#
# + payload - The rebooking request carried by the message
public type RebookingRequestMessage record {|
    *solace:Message;
    RebookingRequest payload;
|};

# Represents a rebooking reply message received by the requester, narrowed so that the
# `RebookingResponse` payload is data-bound directly instead of being delivered as raw `anydata`.
#
# + payload - The rebooking response carried by the message
public type RebookingReplyMessage record {|
    *solace:Message;
    RebookingResponse payload;
|};

# Represents the response returned when a rebooking request is fulfilled.
public type RebookingAccepted record {|
    *http:Ok;
    RebookingResponse body;
|};

# Represents the response returned when no rebooking reply is received within the configured timeout.
public type RebookingTimeout record {|
    *http:GatewayTimeout;
    ErrorDetail body;
|};

# Represents the response returned when the rebooking request could not be published or processed.
public type RebookingError record {|
    *http:InternalServerError;
    ErrorDetail body;
|};
