import ballerinax/ibm.ibmmq;

final ibmmq:QueueManager paymentQueueManager = check new (
    name = queueManagerName,
    host = host,
    port = port,
    channel = channel,
    userID = userID,
    password = password
);

final ibmmq:Queue paymentInstructionsQueue = check paymentQueueManager.accessQueue(
    paymentInstructionsQueueName,
    ibmmq:MQOO_OUTPUT
);

listener ibmmq:Listener paymentResponsesListener = check new (
    name = queueManagerName,
    host = host,
    port = port,
    channel = channel,
    userID = userID,
    password = password
);

// Tracks payment instructions awaiting a response, keyed by the correlation
// ID (hex-encoded) that was set on the outgoing PAYMENT.INSTRUCTIONS message.
// The event-driven consumer on PAYMENT.RESPONSES uses this to correlate an
// incoming response before acknowledging it.
final map<string> pendingPaymentInstructions = {};
