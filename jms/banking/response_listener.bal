import ballerina/log;
import ballerinax/java.jms;

// Core-banking transfer response record expected on CORE.TRANSFER.RESPONSE.
type CoreTransferResponse record {|
    string transferId;
    string status;
    string message?;
|};

listener jms:Listener coreTransferResponseListener = check new (
    connectionConfig = {
        initialContextFactory: "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
        providerUrl: providerUrl
    },
    acknowledgementMode = jms:CLIENT_ACKNOWLEDGE,
    consumerOptions = {
        destination: {
            'type: jms:QUEUE,
            name: "CORE.TRANSFER.RESPONSE"
        }
    }
);

// Tracks redelivery attempts per message, since the connector only exposes a boolean
// `redelivered` flag and not a numeric delivery count. Once a message's attempts exceed
// maxRedeliveryCount, it is routed to CORE.TRANSFER.DLQ instead of being processed further.
isolated class RedeliveryTracker {
    private final map<int> attemptsByMessageId = {};

    isolated function recordAttempt(string messageId) returns int {
        lock {
            int attempts = (self.attemptsByMessageId[messageId] ?: 0) + 1;
            self.attemptsByMessageId[messageId] = attempts;
            return attempts;
        }
    }

    isolated function clear(string messageId) {
        lock {
            _ = self.attemptsByMessageId.removeIfHasKey(messageId);
        }
    }
}

final RedeliveryTracker redeliveryTracker = new;

service "core-transfer-response-consumer" on coreTransferResponseListener {

    // Correlates an inbound core-banking transfer reply to a pending transfer using the JMS
    // correlationId. Matched replies are acknowledged once correlation succeeds; unmatched
    // replies are forwarded to CORE.TRANSFER.UNMATCHED instead of being silently acknowledged.
    // Replies that have been redelivered past maxRedeliveryCount are routed to
    // CORE.TRANSFER.DLQ instead of being processed further.
    remote function onMessage(jms:Message message, jms:Caller caller) returns error? {
        string? messageId = message?.messageId;
        boolean redelivered = message?.redelivered ?: false;

        if redelivered && messageId is string {
            int attempts = redeliveryTracker.recordAttempt(messageId);
            if attempts > maxRedeliveryCount {
                log:printWarn("Core-transfer response exceeded max redelivery count, routing to DLQ",
                        messageId = messageId, attempts = attempts);
                check routeToDlq(message);
                redeliveryTracker.clear(messageId);
                check caller->acknowledge(message);
                return;
            }
        }

        string? correlationId = message?.correlationId;
        if correlationId is () {
            log:printWarn("Received core-transfer response without a correlation id, forwarding to unmatched queue");
            check forwardUnmatchedReply(message);
            check caller->acknowledge(message);
            return;
        }

        if message !is jms:TextMessage {
            log:printWarn("Received non-text core-transfer response, forwarding to unmatched queue", correlationId = correlationId);
            check forwardUnmatchedReply(message);
            check caller->acknowledge(message);
            return;
        }

        CoreTransferResponse|error coreResponse = message.content.fromJsonStringWithType(CoreTransferResponse);
        if coreResponse is error {
            log:printWarn("Failed to parse core-transfer response payload, forwarding to unmatched queue",
                    correlationId = correlationId, 'error = coreResponse);
            check forwardUnmatchedReply(message);
            check caller->acknowledge(message);
            return;
        }

        string? coreMessage = coreResponse?.message;
        boolean correlated = pendingTransferRegistry.correlate(correlationId, coreResponse.status, coreMessage);
        if !correlated {
            log:printWarn("Unmatched core-transfer response, no pending transfer found", correlationId = correlationId);
            check forwardUnmatchedReply(message);
        }

        // Acknowledge only once the reply has either been correlated to a pending transfer, or
        // has been safely forwarded onward to the unmatched queue.
        if messageId is string {
            redeliveryTracker.clear(messageId);
        }
        check caller->acknowledge(message);
    }
}

// Forwards a reply that could not be correlated to a pending transfer onto the unmatched queue,
// preserving the original correlation id and JMS type where present.
function forwardUnmatchedReply(jms:Message message) returns error? {
    jms:TextMessage unmatchedMessage = {
        content: message is jms:TextMessage ? message.content : "",
        correlationId: message?.correlationId,
        jmsType: message?.jmsType
    };
    check coreTransferUnmatchedProducer->send(unmatchedMessage);
}

// Routes a message that has exceeded the max redelivery count to the dead-letter queue,
// preserving the original correlation id and JMS type where present.
function routeToDlq(jms:Message message) returns error? {
    jms:TextMessage dlqMessage = {
        content: message is jms:TextMessage ? message.content : "",
        correlationId: message?.correlationId,
        jmsType: message?.jmsType
    };
    check coreTransferDlqProducer->send(dlqMessage);
}
