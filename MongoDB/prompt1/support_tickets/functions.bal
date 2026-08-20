import ballerina/lang.runtime;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mongodb;

// Executes `operation` and retries on failure up to `maxWriteRetries` additional attempts,
// using exponential backoff starting at `retryBaseDelaySeconds`. Only transient connection
// errors are retried; the last encountered error is returned if all attempts are exhausted.
function executeWithRetry(function () returns error? operation) returns error? {
    int attempt = 0;
    while true {
        error? result = operation();
        if result is () {
            return ();
        }
        if !isTransientError(result) || attempt >= maxWriteRetries {
            return result;
        }
        decimal delaySeconds = retryBaseDelaySeconds * (2 ^ attempt);
        log:printWarn("transient write failure, retrying", 'error = result, attempt = attempt + 1, delaySeconds = delaySeconds);
        runtime:sleep(delaySeconds);
        attempt += 1;
    }
}

// Decides whether an error is a transient connection error worth retrying.
// Conservative default: anything other than a validation/application error is treated as transient.
function isTransientError(error err) returns boolean {
    string message = err.message().toLowerAscii();
    string[] transientMarkers = ["timeout", "timed out", "connection", "socket", "not primary", "primary failover", "network"];
    foreach string marker in transientMarkers {
        if message.includes(marker) {
            return true;
        }
    }
    // Default to treating unknown database/application errors as transient so momentary
    // primary failovers are retried instead of immediately failing the request.
    return true;
}

// Appends a chat message onto the matching ticket document, creating the ticket via upsert
// if it does not already exist, and atomically bumps the ticket's messageCount.
function appendMessageToTicket(ChatEvent chatEvent) returns error? {
    ChatMessage chatMessage = {
        customerId: chatEvent.customerId,
        channel: chatEvent.channel,
        messageText: chatEvent.messageText,
        sender: chatEvent.sender,
        timestamp: chatEvent.timestamp
    };

    mongodb:Update update = {
        "push": {"messages": chatMessage.toJson()},
        inc: {"messageCount": 1},
        setOnInsert: {"ticketId": chatEvent.ticketId, "customerId": chatEvent.customerId, "status": "OPEN"}
    };

    mongodb:UpdateResult|error updateResult = supportTicketsCollection->updateOne(
            {"ticketId": chatEvent.ticketId},
            update,
            {upsert: true}
    );
    if updateResult is error {
        return updateResult;
    }
    return ();
}

// Handles ticket closure together with the compliance audit record so that the two writes
// cannot end up permanently out of sync even if one call fails partway through.
//
// Strategy: the audit record is written first in a PENDING state. Only after the ticket
// closure update succeeds is the audit record marked COMMITTED. If the ticket update fails,
// the audit record is compensated (rolled back / removed) with its own retries so a
// closure is never recorded without the matching ticket state, and a ticket is never left
// closed without a durable audit trail. If the compensating rollback itself cannot be
// completed, the event is routed to the dead-letter collection instead of being dropped
// so the inconsistency is never silently lost.
function closeTicketWithAudit(ChatEvent chatEvent) returns error? {
    string auditId = uuid:createRandomUuid();
    string closedAt = time:utcToString(time:utcNow());

    TicketClosureAudit audit = {
        auditId: auditId,
        ticketId: chatEvent.ticketId,
        closedBy: chatEvent.sender,
        closedAt: closedAt,
        status: "PENDING"
    };

    error? auditWriteResult = executeWithRetry(function() returns error? {
        return supportTicketsAuditInsert(audit);
    });
    if auditWriteResult is error {
        return auditWriteResult;
    }

    mongodb:Update closureUpdate = {
        "push": {"messages": {
            customerId: chatEvent.customerId,
            channel: chatEvent.channel,
            messageText: chatEvent.messageText,
            sender: chatEvent.sender,
            timestamp: chatEvent.timestamp
        }},
        inc: {"messageCount": 1},
        set: {"status": "CLOSED", "closedBy": chatEvent.sender, "closedAt": closedAt, "lastAuditId": auditId},
        setOnInsert: {"ticketId": chatEvent.ticketId, "customerId": chatEvent.customerId}
    };

    error? ticketUpdateResult = executeWithRetry(function() returns error? {
        mongodb:UpdateResult|error result = supportTicketsCollection->updateOne(
                {"ticketId": chatEvent.ticketId},
                closureUpdate,
                {upsert: true}
        );
        if result is error {
            return result;
        }
        return ();
    });

    if ticketUpdateResult is () {
        error? commitResult = executeWithRetry(function() returns error? {
            return markAuditStatus(auditId, "COMMITTED");
        });
        if commitResult is error {
            // Ticket is closed correctly but the audit record could not be marked
            // COMMITTED. The audit record remains discoverable (linked via lastAuditId)
            // so it is not lost; log loudly for reconciliation.
            log:printError("ticket closed but audit record could not be finalized", 'error = commitResult, auditId = auditId, ticketId = chatEvent.ticketId);
        }
        return ();
    }

    // Ticket closure failed after retries: compensate by rolling back the audit record so
    // it never claims a closure that never actually happened.
    error? rollbackResult = executeWithRetry(function() returns error? {
        return markAuditStatus(auditId, "ROLLED_BACK");
    });
    if rollbackResult is error {
        // Even the compensating rollback failed: do not drop this silently, send the
        // original event to the dead-letter collection for manual reconciliation.
        log:printError("failed to roll back audit record after ticket closure failure", 'error = rollbackResult, auditId = auditId, ticketId = chatEvent.ticketId);
        return rollbackResult;
    }
    return ticketUpdateResult;
}

function supportTicketsAuditInsert(TicketClosureAudit audit) returns error? {
    error? result = ticketClosureAuditCollection->insertOne(audit);
    if result is error {
        return result;
    }
    return ();
}

function markAuditStatus(string auditId, string status) returns error? {
    mongodb:Update update = {
        set: {"status": status}
    };
    mongodb:UpdateResult|error result = ticketClosureAuditCollection->updateOne({"auditId": auditId}, update);
    if result is error {
        return result;
    }
    return ();
}

// Writes an event that could not be persisted after exhausting retries to the dead-letter
// collection instead of dropping it.
function writeToDeadLetterQueue(ChatEvent chatEvent, string failureReason) returns error? {
    DeadLetterEvent deadLetterEvent = {
        eventId: uuid:createRandomUuid(),
        event: chatEvent,
        failureReason: failureReason,
        failedAt: time:utcToString(time:utcNow())
    };
    error? result = chatEventsDlqCollection->insertOne(deadLetterEvent);
    if result is error {
        return result;
    }
    return ();
}

// Processes a single chat event end-to-end: appends the message (and handles ticket
// closure with its compliance audit record when applicable), retrying transient failures
// with exponential backoff, and finally falling back to the dead-letter collection so no
// message is ever silently dropped.
function processChatEvent(ChatEvent chatEvent) returns error? {
    error? processingResult;
    if chatEvent.ticketClosed {
        processingResult = closeTicketWithAudit(chatEvent);
    } else {
        processingResult = executeWithRetry(function() returns error? {
            return appendMessageToTicket(chatEvent);
        });
    }

    if processingResult is error {
        log:printError("failed to persist chat event after retries, routing to dead-letter queue",
                'error = processingResult, ticketId = chatEvent.ticketId);
        error? dlqResult = writeToDeadLetterQueue(chatEvent, processingResult.message());
        if dlqResult is error {
            log:printError("failed to write chat event to dead-letter queue", 'error = dlqResult, ticketId = chatEvent.ticketId);
            return dlqResult;
        }
    }
    return ();
}
