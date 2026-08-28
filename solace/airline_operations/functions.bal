import ballerina/uuid;
import ballerinax/solace;

# Builds the hierarchical Solace topic name for a rebooking request of the form
# `airline/rebooking/request/{carrierCode}`.
#
# + carrierCode - The carrier code to derive the topic for
# + return - The hierarchical topic name
function buildRebookingRequestTopic(string carrierCode) returns string {
    return string `airline/rebooking/request/${carrierCode}`;
}

# Builds the hierarchical Solace topic name for a flight event of the form
# `airline/ops/{carrierCode}/{departureAirport}/{eventType}`.
#
# + flightEvent - The flight event to derive the topic for
# + return - The hierarchical topic name
function buildFlightEventTopic(FlightEvent flightEvent) returns string {
    return string `airline/ops/${flightEvent.carrierCode}/${flightEvent.departureAirport}/${flightEvent.eventType}`;
}

# Derives the message priority based on the event type, giving cancellations the highest priority.
#
# + eventType - The category of the flight operational event
# + return - A priority value between 0 (lowest) and 9 (highest)
function derivePriority(EventType eventType) returns int {
    match eventType {
        CANCELLATION => {
            return 9;
        }
        DELAY => {
            return 7;
        }
        GATE_CHANGE => {
            return 6;
        }
        DEPARTED|ARRIVED => {
            return 5;
        }
        BOARDING => {
            return 4;
        }
        _ => {
            return 0;
        }
    }
}

# Publishes a flight operational event onto the Solace PubSub+ topic hierarchy.
#
# + flightEvent - The flight event to publish
# + return - The topic the event was published to, or a `solace:Error` if publishing fails
function publishFlightEvent(FlightEvent flightEvent) returns string|solace:Error {
    string topicName = buildFlightEventTopic(flightEvent);
    int priority = derivePriority(flightEvent.eventType);

    map<solace:Property> properties = {
        flightNumber: flightEvent.flightNumber,
        departureAirport: flightEvent.departureAirport,
        arrivalAirport: flightEvent.arrivalAirport
    };

    solace:Message message = {
        payload: flightEvent,
        deliveryMode: solace:PERSISTENT,
        priority,
        correlationId: flightEvent.eventId,
        properties
    };

    check solaceProducer->send(message, {topicName});
    return topicName;
}

# Processes a disruption event (a DELAY or CANCELLATION flight event) consumed from the
# guaranteed disruptions queue.
#
# + flightEvent - The disruption event to process
# + return - A `TransientProcessingError` if the failure is retryable, a `PermanentProcessingError`
# if it is not, or `()` on success
function processDisruptionEvent(FlightEvent flightEvent) returns TransientProcessingError|PermanentProcessingError? {
    if flightEvent.eventType != DELAY && flightEvent.eventType != CANCELLATION {
        return error PermanentProcessingError(string `Unsupported disruption event type: ${flightEvent.eventType}`);
    }

    int? delayMinutes = flightEvent?.delayMinutes;
    if flightEvent.eventType == DELAY && delayMinutes is () {
        return error PermanentProcessingError("delayMinutes is required when eventType is DELAY");
    }

    // Downstream disruption handling (e.g. rebooking, notifications) would be performed here.
    // A failure to reach a downstream dependency is treated as transient and retried via requeue.
}

# Publishes a passenger rebooking request onto the request topic hierarchy and waits for the
# reply on a dedicated temporary queue.
#
# A temporary queue consumer is created first so that its broker-generated destination name can be
# resolved and used as the `replyTo` address before the request is published, guaranteeing the
# reply-to destination is correct before any message has been received.
#
# + rebookingRequest - The passenger rebooking request to publish
# + return - The rebooking response on success, `()` if no reply arrived within the configured
# timeout, or a `solace:Error` if publishing or consuming fails
function requestRebooking(RebookingRequest rebookingRequest) returns RebookingResponse|solace:Error? {
    solace:MessageConsumer replyConsumer = check new (solaceBrokerUrl,
        messageVpn = solaceVpnName,
        auth = solaceAuthConfig,
        secureSocket = solaceSecureSocket,
        retryConfig = solaceRetryConfig,
        subscriptionConfig = {
            durability: solace:TEMPORARY
        }
    );

    string replyQueueName = replyConsumer->destinationName();
    string correlationId = uuid:createRandomUuid();
    string topicName = buildRebookingRequestTopic(rebookingRequest.carrierCode);

    solace:Message requestMessage = {
        payload: rebookingRequest,
        deliveryMode: solace:PERSISTENT,
        correlationId,
        replyTo: {queueName: replyQueueName}
    };

    solace:Error? sendResult = solaceProducer->send(requestMessage, {topicName});
    if sendResult is solace:Error {
        check replyConsumer->close();
        return sendResult;
    }

    RebookingReplyMessage|solace:Error? replyResult = replyConsumer->receive(rebookingReplyTimeout);
    check replyConsumer->close();

    if replyResult is solace:Error {
        return replyResult;
    }

    if replyResult is () {
        return ();
    }

    return replyResult.payload;
}

# Resolves a passenger rebooking request into a rebooking response.
#
# + rebookingRequest - The passenger rebooking request to resolve
# + return - The rebooking response describing the outcome
function resolveRebooking(RebookingRequest rebookingRequest) returns RebookingResponse {
    // Downstream rebooking logic (e.g. inventory lookup, seat assignment) would be performed here.
    string newFlightNumber = string `${rebookingRequest.originalFlightNumber}-R`;

    return {
        passengerId: rebookingRequest.passengerId,
        originalFlightNumber: rebookingRequest.originalFlightNumber,
        newFlightNumber,
        status: "CONFIRMED"
    };
}
