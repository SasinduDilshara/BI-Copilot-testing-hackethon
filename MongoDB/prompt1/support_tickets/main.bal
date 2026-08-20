import ballerina/http;

listener http:Listener chatEventsListener = new (servicePort);

service /chat on chatEventsListener {

    resource function post events(@http:Payload ChatEvent chatEvent) returns ChatEventAck|http:InternalServerError {
        error? result = processChatEvent(chatEvent);
        if result is error {
            return <http:InternalServerError>{
                body: {message: "failed to process chat event: " + result.message()}
            };
        }
        return {ticketId: chatEvent.ticketId, status: "ACCEPTED"};
    }
}
