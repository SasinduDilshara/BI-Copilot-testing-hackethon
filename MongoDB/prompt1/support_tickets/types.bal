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

// Represents a compliance audit record written when a ticket is closed.
public type TicketClosureAudit record {|
    string auditId;
    string ticketId;
    string closedBy;
    string closedAt;
    // Status of the two-step write: PENDING until the ticket update is confirmed,
    // COMMITTED once both writes are known to be consistent, or ROLLED_BACK if the
    // ticket update failed and this audit record was compensated for.
    string status;
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
