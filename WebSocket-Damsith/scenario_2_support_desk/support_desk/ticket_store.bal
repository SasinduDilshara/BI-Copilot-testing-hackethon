// In-memory ticket store. All state is guarded by lock blocks so the store
// stays safe under the service's concurrent request handling.

import ballerina/time;

isolated table<Ticket> key(ticketId) ticketTable = table [];
isolated int ticketSequence = 0;

isolated function nextTicketId() returns string {
    lock {
        ticketSequence += 1;
        int currentSequence = ticketSequence;
        return string `TKT-${currentSequence}`;
    }
}

isolated function currentTimestamp() returns string {
    time:Utc nowUtc = time:utcNow();
    return time:utcToString(nowUtc);
}

// Builds a ticket from an inbound payload, stores it and returns the stored copy.
isolated function createTicket(TicketCreateRequest createRequest) returns Ticket {
    string generatedId = nextTicketId();
    string createdTime = currentTimestamp();
    TicketPriority requestedPriority = createRequest.ticketPriority ?: defaultTicketPriority;
    string requestedAssignee = createRequest.assignedTo ?: defaultAssignee;

    Ticket newTicket = {
        ticketId: generatedId,
        ticketSubject: createRequest.ticketSubject,
        ticketDescription: createRequest.ticketDescription,
        requesterEmail: createRequest.requesterEmail,
        ticketPriority: requestedPriority,
        ticketStatus: OPEN,
        assignedTo: requestedAssignee,
        createdAt: createdTime,
        updatedAt: createdTime
    };

    lock {
        ticketTable.put(newTicket.clone());
    }
    return newTicket;
}

isolated function findTicket(string ticketId) returns Ticket? {
    lock {
        Ticket? storedTicket = ticketTable[ticketId];
        if storedTicket is Ticket {
            return storedTicket.clone();
        }
        return ();
    }
}

// Returns tickets ordered oldest first, optionally filtered and capped by limit.
isolated function selectTickets(TicketStatus? statusFilter, TicketPriority? priorityFilter, int resultLimit)
        returns Ticket[] {
    lock {
        Ticket[] matchedTickets = from Ticket storedTicket in ticketTable
            where statusFilter is () || storedTicket.ticketStatus == statusFilter
            where priorityFilter is () || storedTicket.ticketPriority == priorityFilter
            order by storedTicket.ticketId ascending
            limit resultLimit
            select storedTicket;
        return matchedTickets.clone();
    }
}

// Applies the non-nil fields of the payload to an existing ticket.
isolated function applyTicketUpdate(string ticketId, TicketUpdateRequest updateRequest) returns Ticket? {
    Ticket? existingTicket = findTicket(ticketId = ticketId);
    if existingTicket is () {
        return ();
    }

    Ticket updatedTicket = existingTicket;
    string? newSubject = updateRequest.ticketSubject;
    if newSubject is string {
        updatedTicket.ticketSubject = newSubject;
    }
    string? newDescription = updateRequest.ticketDescription;
    if newDescription is string {
        updatedTicket.ticketDescription = newDescription;
    }
    TicketPriority? newPriority = updateRequest.ticketPriority;
    if newPriority is TicketPriority {
        updatedTicket.ticketPriority = newPriority;
    }
    TicketStatus? newStatus = updateRequest.ticketStatus;
    if newStatus is TicketStatus {
        updatedTicket.ticketStatus = newStatus;
    }
    string? newAssignee = updateRequest.assignedTo;
    if newAssignee is string {
        updatedTicket.assignedTo = newAssignee;
    }
    updatedTicket.updatedAt = currentTimestamp();

    lock {
        ticketTable.put(updatedTicket.clone());
    }
    return updatedTicket;
}

isolated function countTickets() returns int {
    lock {
        return ticketTable.length();
    }
}
