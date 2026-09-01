import ballerinax/ibm.ibmmq;

// Binds a raw IBM MQ message received on CLAIMS.INBOUND to a typed
// ClaimSubmission record.
function mapToClaimSubmission(ibmmq:Message claimMessage) returns ClaimSubmission|error {
    string payloadText = check string:fromBytes(claimMessage.payload);
    return payloadText.fromJsonStringWithType(ClaimSubmission);
}

// Records a delivery attempt for a claim message, keyed by its message ID,
// and returns the delivery count reported so far. The ibmmq:Message record
// does not expose the queue manager's native backout count, so this
// application-level counter is used instead: a rollback redelivers the
// message unchanged (same message ID), so each redelivery increments the
// count kept for that message ID.
function recordDeliveryAttempt(ibmmq:Message claimMessage) returns int {
    byte[]? messageIdBytes = claimMessage.messageId;
    string messageKey = messageIdBytes is byte[] ? messageIdBytes.toBase16() : "";
    lock {
        int currentDeliveryCount = claimDeliveryAttempts[messageKey] ?: 0;
        currentDeliveryCount += 1;
        claimDeliveryAttempts[messageKey] = currentDeliveryCount;
        return currentDeliveryCount;
    }
}

// Clears the tracked delivery attempts for a claim message once it has
// either been committed successfully or routed to the dead-letter queue.
function clearDeliveryAttempts(ibmmq:Message claimMessage) {
    byte[]? messageIdBytes = claimMessage.messageId;
    string messageKey = messageIdBytes is byte[] ? messageIdBytes.toBase16() : "";
    lock {
        _ = claimDeliveryAttempts.removeIfHasKey(messageKey);
    }
}

// Maps a claim submission that exceeded the maximum delivery attempts into
// a dead-letter message, carrying the failure reason and attempt count as
// message properties.
function mapToDeadLetterMessage(ibmmq:Message claimMessage, string failureReason, int deliveryCount) returns ibmmq:Message => {
    payload: claimMessage.payload,
    correlationId: claimMessage.correlationId,
    persistence: MQ_PERSISTENCE_PERSISTENT,
    properties: {
        "failureReason": {value: failureReason},
        "deliveryCount": {value: deliveryCount}
    }
};

// IBM MQ persistence value indicating the message survives queue manager restarts.
const int MQ_PERSISTENCE_PERSISTENT = 1;
