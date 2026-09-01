import ballerinax/ibm.ibmmq;

final ibmmq:QueueManager claimsQueueManager = check new (
    name = queueManagerName,
    host = host,
    port = port,
    channel = channel,
    userID = userID,
    password = password
);

final ibmmq:Queue claimsDlq = check claimsQueueManager.accessQueue(
    claimsDlqName,
    ibmmq:MQOO_OUTPUT
);

listener ibmmq:Listener claimsInboundListener = check new (
    name = queueManagerName,
    host = host,
    port = port,
    channel = channel,
    userID = userID,
    password = password
);

// Tracks delivery attempts per claim message, keyed by the message ID
// (hex-encoded). The ibmmq:Message record does not expose the queue
// manager's native backout count, so redeliveries of the same message
// (identical message ID, since a rollback redelivers the message
// unchanged) are counted here to detect poison messages.
final map<int> claimDeliveryAttempts = {};
