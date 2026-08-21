import ballerina/http;

listener http:Listener chatEventsListener = new (servicePort);

service /chat on chatEventsListener {

    resource function post events(@http:Payload ChatEvent chatEvent) returns ChatEventAck|http:NotFound|http:InternalServerError {
        error? result = processChatEvent(chatEvent);
        if result is TicketNotFoundError {
            return <http:NotFound>{
                body: {message: result.message()}
            };
        }
        if result is error {
            return <http:InternalServerError>{
                body: {message: "failed to process chat event: " + result.message()}
            };
        }
        return {ticketId: chatEvent.ticketId, status: "ACCEPTED"};
    }
}

service /tickets on chatEventsListener {

    resource function post create(@http:Payload TicketCreateRequest ticketCreateRequest) returns TicketCreateAck|http:InternalServerError {
        error? result = createTicket(ticketCreateRequest);
        if result is error {
            return <http:InternalServerError>{
                body: {message: "failed to create ticket: " + result.message()}
            };
        }
        return {ticketId: ticketCreateRequest.ticketId, status: "CREATED"};
    }
}
