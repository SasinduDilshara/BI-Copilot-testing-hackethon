import ballerinax/ibm.ibmmq;

// IBM MQ persistence value indicating the message survives queue manager restarts.
const int MQ_PERSISTENCE_PERSISTENT = 1;

// Maps a PaymentInstruction into an IBM MQ message, setting the correlation ID,
// priority, persistence, expiry, and custom message properties carrying the
// routing information (scheme and originating branch).
function mapToPaymentInstructionMessage(PaymentInstruction paymentInstruction, byte[] correlationId) returns ibmmq:Message => {
    payload: paymentInstruction.toJsonString().toBytes(),
    correlationId: correlationId,
    priority: 5,
    persistence: MQ_PERSISTENCE_PERSISTENT,
    expiry: 6000,
    properties: {
        "scheme": {value: paymentInstruction.scheme},
        "originatingBranch": {value: paymentInstruction.originatingBranch}
    }
};

// Maps a raw IBM MQ message read from PAYMENT.RESPONSES into a PaymentResponse.
function mapToPaymentResponse(ibmmq:Message responseMessage, string instructionId) returns PaymentResponse|error {
    byte[]? correlationIdBytes = responseMessage.correlationId;
    string correlationId = correlationIdBytes is byte[] ? check string:fromBytes(correlationIdBytes) : "";
    string status = check string:fromBytes(responseMessage.payload);
    return {
        instructionId,
        correlationId,
        status
    };
}
