// Support desk HTTP API: create, list and update tickets.

import ballerina/http;
import ballerina/log;

listener http:Listener ticketListener = new (servicePort);

service /api/v1 on ticketListener {

    // POST /api/v1/tickets - creates a ticket and returns it with its generated id.
    resource function post tickets(TicketCreateRequest createRequest) returns http:Created|http:BadRequest {
        ErrorPayload? validationError = validateCreateRequest(createRequest = createRequest);
        if validationError is ErrorPayload {
            return <http:BadRequest>{body: validationError};
        }

        Ticket createdTicket = createTicket(createRequest = createRequest);
        string createdId = createdTicket.ticketId;
        log:printInfo("ticket created", ticketId = createdId);
        return <http:Created>{
            body: createdTicket,
            headers: {"Location": string `/api/v1/tickets/${createdId}`}
        };
    }

    // GET /api/v1/tickets?status=OPEN&priority=HIGH&limit=20
    resource function get tickets(string? status = (), string? priority = (), int? 'limit = ())
            returns TicketList|http:BadRequest {
        TicketStatus? statusFilter = ();
        if status is string {
            TicketStatus|error convertedStatus = status.cloneWithType();
            if convertedStatus is error {
                return <http:BadRequest>{
                    body: {errorMessage: "invalid status filter", errorDetail: status}
                };
            }
            statusFilter = convertedStatus;
        }

        TicketPriority? priorityFilter = ();
        if priority is string {
            TicketPriority|error convertedPriority = priority.cloneWithType();
            if convertedPriority is error {
                return <http:BadRequest>{
                    body: {errorMessage: "invalid priority filter", errorDetail: priority}
                };
            }
            priorityFilter = convertedPriority;
        }

        int resultLimit = maxPageSize;
        if 'limit is int {
            if 'limit < 1 {
                return <http:BadRequest>{body: {errorMessage: "limit must be greater than zero"}};
            }
            resultLimit = 'limit < maxPageSize ? 'limit : maxPageSize;
        }

        Ticket[] matchedTickets = selectTickets(
            statusFilter = statusFilter,
            priorityFilter = priorityFilter,
            resultLimit = resultLimit
        );
        return {totalCount: matchedTickets.length(), ticketItems: matchedTickets};
    }

    // GET /api/v1/tickets/{ticketId}
    resource function get tickets/[string ticketId]() returns Ticket|http:NotFound {
        Ticket? storedTicket = findTicket(ticketId = ticketId);
        if storedTicket is Ticket {
            return storedTicket;
        }
        return <http:NotFound>{body: {errorMessage: "ticket not found", errorDetail: ticketId}};
    }

    // PUT /api/v1/tickets/{ticketId} - applies only the fields present in the payload.
    resource function put tickets/[string ticketId](TicketUpdateRequest updateRequest)
            returns Ticket|http:BadRequest|http:NotFound {
        ErrorPayload? validationError = validateUpdateRequest(updateRequest = updateRequest);
        if validationError is ErrorPayload {
            return <http:BadRequest>{body: validationError};
        }

        Ticket? updatedTicket = applyTicketUpdate(ticketId = ticketId, updateRequest = updateRequest);
        if updatedTicket is Ticket {
            log:printInfo("ticket updated", ticketId = ticketId);
            return updatedTicket;
        }
        return <http:NotFound>{body: {errorMessage: "ticket not found", errorDetail: ticketId}};
    }
}
