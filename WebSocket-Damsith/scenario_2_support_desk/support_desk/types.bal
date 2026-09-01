// Domain records and API payload shapes for the support desk service.

public enum TicketStatus {
    OPEN = "OPEN",
    IN_PROGRESS = "IN_PROGRESS",
    RESOLVED = "RESOLVED",
    CLOSED = "CLOSED"
}

public enum TicketPriority {
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    URGENT = "URGENT"
}

public type Ticket record {|
    readonly string ticketId;
    string ticketSubject;
    string ticketDescription;
    string requesterEmail;
    TicketPriority ticketPriority;
    TicketStatus ticketStatus;
    string assignedTo;
    string createdAt;
    string updatedAt;
|};

// Inbound payload for POST /tickets. Priority and assignee fall back to config.
public type TicketCreateRequest record {|
    string ticketSubject;
    string ticketDescription;
    string requesterEmail;
    TicketPriority ticketPriority?;
    string assignedTo?;
|};

// Inbound payload for PATCH /tickets/{ticketId}. Every field is optional.
public type TicketUpdateRequest record {|
    string ticketSubject?;
    string ticketDescription?;
    TicketPriority ticketPriority?;
    TicketStatus ticketStatus?;
    string assignedTo?;
|};

public type TicketList record {|
    int totalCount;
    Ticket[] ticketItems;
|};

public type ErrorPayload record {|
    string errorMessage;
    string errorDetail?;
|};
