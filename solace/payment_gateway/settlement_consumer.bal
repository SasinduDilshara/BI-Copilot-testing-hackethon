import ballerina/log;
import ballerinax/solace;

# Consumes payment instructions from the durable queue `PAYMENTS.INSTRUCTIONS.IN` with client
# acknowledgement, validates each instruction, and republishes it onto `PAYMENTS.SETTLEMENT.OUT`
# (or the dead letter queue for poison/invalid instructions) before acknowledging the source
# message. See `processSettlement` in functions.bal.
#
# This gives at-least-once delivery rather than the exactly-once-per-transaction semantics of a
# transacted session: the outbound publish and the ack of the source message are two separate,
# uncoordinated steps, so a crash between them leaves the instruction unacknowledged and it is
# redelivered on reconnect/restart. A redelivery is detected via the message's `deliveryCount`
# (see `isRedelivery` in functions.bal) rather than the previous sequence-number dedup, and the
# settlement/DLQ publish is skipped on that redelivery so it is not republished a second time -
# only the ack is repeated.
@solace:ServiceConfig {
    queueName: paymentInstructionsQueueName,
    ackMode: solace:CLIENT_ACK
}
service on settlementListener {

    # Invoked for every payment instruction delivered from `PAYMENTS.INSTRUCTIONS.IN`.
    #
    # + message - The payment instruction message, with the payload data-bound into
    # `PaymentInstruction`
    # + caller - Handle used to acknowledge or negatively acknowledge the message
    # + return - A `solace:Error` if acknowledgement/negative-acknowledgement itself fails
    remote function onMessage(PaymentInstructionMessage message, solace:Caller caller) returns solace:Error? {
        PaymentInstruction paymentInstruction = message.payload;

        solace:Error? result = processSettlement(message, caller);
        if result is solace:Error {
            log:printError("Failed to settle payment instruction, requeuing",
                    instructionId = paymentInstruction.instructionId, 'error = result);
            return result;
        }

        log:printInfo("Payment instruction settlement processed", instructionId = paymentInstruction.instructionId);
    }

    # Invoked when a delivered message cannot be dispatched to `onMessage`, most commonly because
    # the underlying guaranteed consumer flow is disrupted.
    #
    # + err - The failure that prevented dispatch
    remote function onError(solace:Error err) returns solace:Error? {
        if err is solace:FlowDownError {
            log:printError("Settlement consumer flow is down; the underlying connection was lost " +
                    "and the flow will be re-established once connectivity is restored", 'error = err);
            return;
        }

        if err is solace:InactiveFlowError {
            log:printWarn("Settlement consumer flow is inactive; another instance in the client " +
                    "cluster is likely active and this instance will remain on standby", 'error = err);
            return;
        }

        log:printError("Unexpected error while consuming payment instructions", 'error = err);
    }
}
