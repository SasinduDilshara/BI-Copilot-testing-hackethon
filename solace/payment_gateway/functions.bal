import ballerina/time;
import ballerinax/solace;

# In-memory audit trail of processed payment instructions. The audit write is an append-only log
# and no longer needs to be atomic with the publish to `PAYMENTS.INSTRUCTIONS.IN`.
final table<AuditEntry> key(instructionId) auditEntries = table [];

# Builds an audit entry for a payment instruction, timestamped with the current UTC time.
#
# + paymentInstruction - The payment instruction to build the audit entry for
# + return - The audit entry to be recorded
function buildAuditEntry(PaymentInstruction paymentInstruction) returns AuditEntry => {
    instructionId: paymentInstruction.instructionId,
    debtorIban: paymentInstruction.debtorIban,
    creditorIban: paymentInstruction.creditorIban,
    amount: paymentInstruction.amount,
    currency: paymentInstruction.currency,
    executionDate: paymentInstruction.executionDate,
    paymentScheme: paymentInstruction.paymentScheme,
    recordedTime: time:utcToString(time:utcNow())
};

# Records the audit entry for a payment instruction in the append-only in-memory audit log.
#
# + auditEntry - The audit entry to record
function writeAuditEntry(AuditEntry auditEntry) {
    auditEntries.add(auditEntry);
}

# Publishes a payment instruction onto the guaranteed `PAYMENTS.INSTRUCTIONS.IN` queue and records
# its audit entry as an independent, best-effort append to the audit log.
#
# The publish and the audit write are no longer coupled by a transaction: the publish is the
# source of truth for the instruction, and the audit write is fire-and-forget append-only logging
# that is not rolled back if it fails after a successful publish.
#
# + paymentInstruction - The payment instruction to process
# + return - `()` if the publish succeeded, or a `solace:Error` if the publish failed
function processPaymentInstruction(PaymentInstruction paymentInstruction) returns solace:Error? {
    solace:Message message = {
        payload: paymentInstruction,
        deliveryMode: solace:PERSISTENT,
        correlationId: paymentInstruction.instructionId
    };

    check paymentInstructionProducer->send(message, {queueName: paymentInstructionsQueueName});

    AuditEntry auditEntry = buildAuditEntry(paymentInstruction);
    writeAuditEntry(auditEntry);
}

# Validates a payment instruction consumed from `PAYMENTS.INSTRUCTIONS.IN`.
#
# + paymentInstruction - The payment instruction to validate
# + return - A `ValidationError` describing the first validation failure found, or `()` if the
# instruction is valid
function validatePaymentInstruction(PaymentInstruction paymentInstruction) returns ValidationError? {
    if paymentInstruction.debtorIban.trim().length() == 0 {
        return error ValidationError("debtorIban must not be empty");
    }
    if paymentInstruction.creditorIban.trim().length() == 0 {
        return error ValidationError("creditorIban must not be empty");
    }
    if paymentInstruction.amount <= 0d {
        return error ValidationError("amount must be greater than zero");
    }
    if paymentInstruction.currency.trim().length() == 0 {
        return error ValidationError("currency must not be empty");
    }
    if paymentInstruction.paymentScheme.trim().length() == 0 {
        return error ValidationError("paymentScheme must not be empty");
    }
}

# Builds the settled payment instruction to be published onto `PAYMENTS.SETTLEMENT.OUT`.
#
# + paymentInstruction - The payment instruction that was validated
# + return - The settled payment instruction
function buildSettledPaymentInstruction(PaymentInstruction paymentInstruction) returns SettledPaymentInstruction => {
    instructionId: paymentInstruction.instructionId,
    debtorIban: paymentInstruction.debtorIban,
    creditorIban: paymentInstruction.creditorIban,
    amount: paymentInstruction.amount,
    currency: paymentInstruction.currency,
    executionDate: paymentInstruction.executionDate,
    paymentScheme: paymentInstruction.paymentScheme
};

# Checks whether a payment instruction message is being redelivered, based on the broker-reported
# `deliveryCount`. A `deliveryCount` greater than one means this message was previously delivered
# and left unacknowledged - most likely because the consumer crashed or disconnected after
# publishing to `PAYMENTS.SETTLEMENT.OUT`/the DLQ but before acknowledging it - so it must not be
# republished a second time.
#
# + message - The payment instruction message received from `PAYMENTS.INSTRUCTIONS.IN`
# + return - `true` if this delivery is a redelivery of a previously delivered message
function isRedelivery(PaymentInstructionMessage message) returns boolean {
    int? deliveryCount = message?.deliveryCount;
    if deliveryCount is () {
        return false;
    }
    return deliveryCount > 1;
}

# Determines whether a payment instruction message has exceeded the configured maximum delivery
# count and should be treated as poison, routed to the dead letter queue instead of being retried
# again.
#
# + message - The payment instruction message received from `PAYMENTS.INSTRUCTIONS.IN`
# + return - `true` if the message's delivery count has exceeded `maxDeliveryCount`
function isPoisonMessage(PaymentInstructionMessage message) returns boolean {
    int? deliveryCount = message?.deliveryCount;
    if deliveryCount is () {
        return false;
    }
    return deliveryCount > maxDeliveryCount;
}

# Publishes a message onto the dead letter queue.
#
# + paymentInstruction - The payment instruction to dead-letter
# + reason - Human readable description of why the instruction was dead-lettered
# + return - A `solace:Error` if the publish fails
function publishToDlq(PaymentInstruction paymentInstruction, string reason) returns solace:Error? {
    solace:Message dlqMessage = {
        payload: paymentInstruction,
        deliveryMode: solace:PERSISTENT,
        correlationId: paymentInstruction.instructionId,
        properties: {
            dlqReason: reason
        }
    };
    check settlementProducer->send(dlqMessage, {queueName: paymentInstructionsDlqName});
}

# Processes a payment instruction message consumed from `PAYMENTS.INSTRUCTIONS.IN`: skips
# republishing on a redelivery (detected via `deliveryCount`), routes poison messages (those whose
# delivery count has exceeded `maxDeliveryCount`) and instructions that fail validation to the dead
# letter queue, and otherwise republishes a settled instruction onto `PAYMENTS.SETTLEMENT.OUT`,
# each carrying the instruction ID as its correlation ID. The source message is only acknowledged
# once the outbound publish (or the redelivery check) has completed successfully.
#
# This is at-least-once processing, not exactly-once: the outbound publish and the ack of the
# source message are two separate, uncoordinated operations, so a crash after the publish but
# before the ack causes a redelivery. That redelivery is recognized via `deliveryCount` so it is
# not republished again, but the ack is retried.
#
# + message - The payment instruction message received from `PAYMENTS.INSTRUCTIONS.IN`
# + caller - Handle used to acknowledge or negatively acknowledge the message
# + return - A `solace:Error` if the outbound publish fails (the message is then negatively
# acknowledged and requeued), or if acknowledgement/negative-acknowledgement itself fails
function processSettlement(PaymentInstructionMessage message, solace:Caller caller) returns solace:Error? {
    PaymentInstruction paymentInstruction = message.payload;

    if isRedelivery(message) {
        // Already published to the settlement queue or the DLQ on a prior delivery; this
        // redelivery only needs to be acknowledged, not republished again.
        check caller->ack(message);
        return;
    }

    if isPoisonMessage(message) {
        solace:Error? dlqResult = publishToDlq(paymentInstruction,
                string `Exceeded maximum delivery count of ${maxDeliveryCount}`);
        return finalizeSettlement(dlqResult, message, caller);
    }

    ValidationError? validationResult = validatePaymentInstruction(paymentInstruction);
    if validationResult is ValidationError {
        solace:Error? dlqResult = publishToDlq(paymentInstruction, validationResult.message());
        return finalizeSettlement(dlqResult, message, caller);
    }

    SettledPaymentInstruction settledPaymentInstruction = buildSettledPaymentInstruction(paymentInstruction);
    solace:Message settlementMessage = {
        payload: settledPaymentInstruction,
        deliveryMode: solace:PERSISTENT,
        correlationId: paymentInstruction.instructionId
    };

    solace:Error? sendResult = settlementProducer->send(settlementMessage, {queueName: settlementOutQueueName});
    return finalizeSettlement(sendResult, message, caller);
}

# Acknowledges or negatively acknowledges the source message based on the outcome of the
# producer-side publish (to the settlement queue or the DLQ).
#
# + publishResult - The outcome of the settlement producer's publish operation
# + message - The payment instruction message being settled
# + caller - Handle used to acknowledge or negatively acknowledge the message
# + return - A `solace:Error` if acknowledgement/negative-acknowledgement itself fails
function finalizeSettlement(solace:Error? publishResult, PaymentInstructionMessage message, solace:Caller caller)
        returns solace:Error? {
    if publishResult is solace:Error {
        check caller->nack(message, requeue = true);
        return publishResult;
    }

    check caller->ack(message);
}
