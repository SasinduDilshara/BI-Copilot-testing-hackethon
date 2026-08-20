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

// Handles ticket closure together with the compliance audit record, which is now written
// to its own standalone ticket_audit_log collection (separate retention / legal-hold
// policies) rather than embedded in the ticket document.
//
// IMPORTANT GUARANTEE: with two independent writes to two separate collections and no
// multi-document transaction support in the connector, we CANNOT guarantee atomicity
// across the ticket update and the audit insert. If the process crashes between the two
// writes, the ticket and its audit trail can be left out of sync. What we DO guarantee is
// detectability:
//   1. The ticket update happens FIRST and, in the same atomic operation, stamps the
//      ticket with auditStatus: "PENDING" and the auditId that will be used for the audit
//      record. This ordering is deliberate: a crash before this point means the closure
//      never happened at all (nothing to reconcile). A crash after it means the ticket is
//      durably marked as closed AND carries a breadcrumb that its audit record is still
//      outstanding.
//   2. Only after the ticket update is confirmed do we attempt to insert the audit
//      record. If that succeeds, the ticket is flipped to auditStatus: "RECORDED".
//   3. If the audit insert fails even after retries, we deliberately do NOT drop the
//      event and do NOT send it to the DLQ (the ticket closure itself is valid and
//      already durable) — we leave auditStatus: "PENDING" on the ticket so it can be
//      found and reconciled later by reconcilePendingAuditWrites().
// This means we never produce a phantom audit record for a closure that did not happen
// (false positive), at the cost of a possible short window where a closed ticket's audit
// record has not been written yet (a detectable, reconcilable false negative).
function closeTicketWithAudit(ChatEvent chatEvent) returns error? {
    string auditId = uuid:createRandomUuid();
    string closedAt = time:utcToString(time:utcNow());

    mongodb:Update closureUpdate = {
        "push": {"messages": {
            customerId: chatEvent.customerId,
            channel: chatEvent.channel,
            messageText: chatEvent.messageText,
            sender: chatEvent.sender,
            timestamp: chatEvent.timestamp
        }},
        inc: {"messageCount": 1},
        set: {
            "status": "CLOSED",
            "closedBy": chatEvent.sender,
            "closedAt": closedAt,
            "auditId": auditId,
            "auditStatus": "PENDING"
        },
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

    // Ticket closure failed after retries: nothing was durably recorded, so this event
    // is handled the same way as any other failed write (falls through to the DLQ).
    if ticketUpdateResult is error {
        return ticketUpdateResult;
    }

    TicketClosureAudit audit = {
        auditId: auditId,
        ticketId: chatEvent.ticketId,
        closedBy: chatEvent.sender,
        closedAt: closedAt
    };

    error? auditWriteResult = executeWithRetry(function() returns error? {
        return ticketAuditLogInsert(audit);
    });

    if auditWriteResult is error {
        // The ticket is correctly closed but the audit record could not be written.
        // Leave auditStatus: "PENDING" in place (already durable from the ticket update
        // above) so this ticket is picked up by reconcilePendingAuditWrites() instead of
        // the inconsistency being silently lost.
        log:printError("ticket closed but audit record could not be written; left PENDING for reconciliation",
                'error = auditWriteResult, auditId = auditId, ticketId = chatEvent.ticketId);
        return ();
    }

    error? markResult = markTicketAuditRecorded(chatEvent.ticketId, auditId);
    if markResult is error {
        // The audit record itself is safely written; only the ticket's bookkeeping flag
        // could not be flipped. Reconciliation will find this ticket still PENDING, check
        // ticket_audit_log, discover the record already exists, and simply flip the flag
        // rather than write a duplicate audit record.
        log:printError("audit record written but ticket auditStatus could not be updated to RECORDED",
                'error = markResult, auditId = auditId, ticketId = chatEvent.ticketId);
    }
    return ();
}

function ticketAuditLogInsert(TicketClosureAudit audit) returns error? {
    error? result = ticketAuditLogCollection->insertOne(audit);
    if result is error {
        return result;
    }
    return ();
}

function markTicketAuditRecorded(string ticketId, string auditId) returns error? {
    mongodb:Update update = {
        set: {"auditStatus": "RECORDED"}
    };
    mongodb:UpdateResult|error result = supportTicketsCollection->updateOne(
            {"ticketId": ticketId, "auditId": auditId},
            update
    );
    if result is error {
        return result;
    }
    return ();
}

// Reconciliation sweep: finds tickets whose audit write did not complete (auditStatus
// still "PENDING") and retries writing their audit record to ticket_audit_log. Safe to
// call repeatedly (e.g. from a scheduled job) since it checks for an existing audit
// record before inserting, so a ticket is never given two audit entries for the same
// closure. Returns the number of tickets successfully reconciled.
function reconcilePendingAuditWrites() returns int|error {
    stream<TicketAuditPointer, error?> pendingTickets =
        check supportTicketsCollection->find({"auditStatus": "PENDING"}, targetType = TicketAuditPointer);

    int reconciledCount = 0;
    error? streamError = pendingTickets.forEach(function(TicketAuditPointer ticketPointer) {
        error? reconcileResult = reconcileSingleTicket(ticketPointer);
        if reconcileResult is error {
            log:printError("failed to reconcile pending audit write", 'error = reconcileResult, ticketId = ticketPointer.ticketId);
        } else {
            reconciledCount += 1;
        }
    });
    check pendingTickets.close();
    if streamError is error {
        return streamError;
    }
    return reconciledCount;
}

function reconcileSingleTicket(TicketAuditPointer ticketPointer) returns error? {
    string? auditId = ticketPointer.auditId;
    string? closedBy = ticketPointer.closedBy;
    string? closedAt = ticketPointer.closedAt;
    if auditId is () || closedBy is () || closedAt is () {
        return error(string `ticket ${ticketPointer.ticketId} is missing closure fields required for reconciliation`);
    }

    TicketClosureAudit|error? existingAudit = ticketAuditLogCollection->findOne(
            {"auditId": auditId},
            targetType = TicketClosureAudit
    );
    if existingAudit is error {
        return existingAudit;
    }
    if existingAudit is () {
        TicketClosureAudit audit = {
            auditId: auditId,
            ticketId: ticketPointer.ticketId,
            closedBy: closedBy,
            closedAt: closedAt
        };
        error? insertResult = ticketAuditLogInsert(audit);
        if insertResult is error {
            return insertResult;
        }
    }
    return markTicketAuditRecorded(ticketPointer.ticketId, auditId);
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
