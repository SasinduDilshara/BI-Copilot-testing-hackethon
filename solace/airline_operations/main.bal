import ballerina/http;
import ballerinax/solace;

service /ops on new http:Listener(servicePort) {

    # Accepts a flight operational event and publishes it onto the Solace PubSub+ topic hierarchy.
    #
    # + flightEvent - The flight operational event to publish
    # + return - The acknowledgement on success, or an error response on failure
    resource function post flight\-events(@http:Payload FlightEvent flightEvent)
            returns FlightEventAccepted|FlightEventBadRequest|FlightEventPublishError {

        int? delayMinutes = flightEvent?.delayMinutes;
        if flightEvent.eventType == DELAY && delayMinutes is () {
            return <FlightEventBadRequest>{
                body: {
                    message: "delayMinutes is required when eventType is DELAY"
                }
            };
        }

        string|solace:Error result = publishFlightEvent(flightEvent);
        if result is solace:Error {
            return <FlightEventPublishError>{
                body: {
                    message: string `Failed to publish flight event: ${result.message()}`
                }
            };
        }

        return <FlightEventAccepted>{
            body: {
                eventId: flightEvent.eventId,
                topic: result
            }
        };
    }

    # Publishes a passenger rebooking request and waits for the responder's reply.
    #
    # + rebookingRequest - The passenger rebooking request to publish
    # + return - The rebooking response on success, a gateway timeout if no reply arrives in time,
    # or an error response on failure
    resource function post rebooking(@http:Payload RebookingRequest rebookingRequest)
            returns RebookingAccepted|RebookingTimeout|RebookingError {

        RebookingResponse|solace:Error? result = requestRebooking(rebookingRequest);

        if result is solace:Error {
            return <RebookingError>{
                body: {
                    message: string `Failed to process rebooking request: ${result.message()}`
                }
            };
        }

        if result is () {
            return <RebookingTimeout>{
                body: {
                    message: "Timed out waiting for a rebooking response"
                }
            };
        }

        return <RebookingAccepted>{
            body: result
        };
    }
}
