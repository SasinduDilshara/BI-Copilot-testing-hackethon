// Support desk HTTP API: create, list and update tickets.

import ballerina/http;
import ballerina/log;
import ballerina/websocket;

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
        broadcastTicketEvent(eventType = TICKET_CREATED, ticket = createdTicket);
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
            broadcastTicketEvent(eventType = TICKET_UPDATED, ticket = updatedTicket);
            return updatedTicket;
        }
        return <http:NotFound>{body: {errorMessage: "ticket not found", errorDetail: ticketId}};
    }
}

// WebSocket upgrade endpoint: agents connect here to receive ticket
// created/updated events pushed in real time instead of polling the HTTP API.
// Runs on its own listener/port: sharing ticketListener would attach two
// service-dispatch mechanisms (http:Service + websocket upgrade) to the same
// http:Listener instance, which fails the upgrade with an unlogged 500.
// The existing HTTP contract on servicePort is completely untouched.
service /tickets/live on new websocket:Listener(liveServicePort) {

    // Initial queues can be selected via ?queue=hana&queue=nora on the upgrade
    // request. The selection can be changed later over the same connection
    // by sending a QueueSubscriptionUpdate message.
    resource function get .(http:Request request) returns websocket:Service|websocket:UpgradeError {
        string[]? requestedQueues = request.getQueryParamValues("queue");
        string[] initialQueues = requestedQueues is string[] ? requestedQueues : [];
        return new TicketLiveService(initialQueues);
    }
}

service class TicketLiveService {
    *websocket:Service;

    private final string[] initialQueues;

    function init(string[] initialQueues) {
        self.initialQueues = initialQueues;
    }

    remote function onOpen(websocket:Caller caller) returns error? {
        registerTicketSubscriber(caller, self.initialQueues);
        log:printInfo("agent connected to ticket live feed",
            connectionId = caller.getConnectionId(), queues = self.initialQueues);
    }

    // Lets an agent change their queue selection without reconnecting.
    // The update is trapped so that an unexpected panic here - from this or
    // any future bug - only fails this one message/connection instead of
    // taking down the whole service (which would also kill the unrelated
    // HTTP API sharing the same process).
    remote function onMessage(websocket:Caller caller, QueueSubscriptionUpdate subscriptionUpdate)
            returns QueueSubscriptionAck|error? {
        string[]|error subscriptionResult = trap updateTicketSubscription(
                caller = caller, subscriptionUpdate = subscriptionUpdate);
        if subscriptionResult is error {
            log:printError("failed to apply queue subscription update",
                connectionId = caller.getConnectionId(), 'error = subscriptionResult);
            return error("failed to apply subscription update");
        }
        string[] subscribedQueues = subscriptionResult;
        log:printInfo("agent updated queue subscription",
            connectionId = caller.getConnectionId(), queues = subscribedQueues);
        return {subscribedQueues};
    }

    remote function onClose(websocket:Caller caller, int statusCode, string reason) {
        deregisterTicketSubscriber(caller);
        log:printInfo("agent disconnected from ticket live feed", connectionId = caller.getConnectionId());
    }

    remote function onError(websocket:Caller caller, error err) returns error? {
        deregisterTicketSubscriber(caller);
        log:printWarn("ticket live feed connection error", connectionId = caller.getConnectionId(), 'error = err);
    }
}
