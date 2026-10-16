// Represents an inbound live-chat transcript event received over HTTP.
public type ChatEvent record {|
    string ticketId;
    string customerId;
    string channel;
    string messageText;
    string sender;
    string timestamp;
    // When true, this event indicates the ticket is being closed by `sender`.
    boolean ticketClosed = false;
|};

// Represents a single chat message embedded inside a ticket document.
public type ChatMessage record {|
    string customerId;
    string channel;
    string messageText;
    string sender;
    string timestamp;
|};

// Represents a compliance audit record written to the standalone ticket_audit_log
// collection when a ticket is closed. This collection is kept separate from the ticket
// document itself since it is subject to its own retention / legal-hold policies.
public type TicketClosureAudit record {|
    string auditId;
    string ticketId;
    string closedBy;
    string closedAt;
|};

// Projection of a ticket document used during audit-write reconciliation: just enough
// fields to know which audit record still needs to be (re)written.
public type TicketAuditPointer record {|
    string ticketId;
    string? auditId = ();
    string? closedBy = ();
    string? closedAt = ();
|};

// Represents a chat event that could not be persisted after exhausting retries.
public type DeadLetterEvent record {|
    string eventId;
    ChatEvent event;
    string failureReason;
    string failedAt;
|};

// Response returned to the caller once a chat event has been processed.
public type ChatEventAck record {|
    string ticketId;
    string status;
|};

// Request to explicitly create a new support ticket before any chat event can attach to it.
public type TicketCreateRequest record {|
    string ticketId;
    string customerId;
|};

// Response returned once a ticket has been created.
public type TicketCreateAck record {|
    string ticketId;
    string status;
|};

// Minimal projection used to check for a ticket's existence without pulling the whole document.
public type TicketExistencePointer record {|
    string ticketId;
|};
