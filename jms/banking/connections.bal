import ballerinax/activemq.driver as _;
import ballerinax/java.jms;

final jms:Connection jmsConnection = check new (
    initialContextFactory = "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
    providerUrl = providerUrl
);

// Session used for the transfer submission path. Uses client acknowledgement since the audit
// write now happens in its own service and no longer needs to be committed atomically with the
// JMS send.
final jms:Session jmsTransferSession = check createJmsSession(jmsConnection, jms:CLIENT_ACKNOWLEDGE);

final jms:MessageProducer coreTransferRequestProducer = check jmsTransferSession.createProducer({
    'type: jms:QUEUE,
    name: "CORE.TRANSFER.REQUEST"
});

// Separate session used to forward replies that could not be correlated to a pending transfer
// onward to the unmatched queue, and replies that have exceeded the max redelivery count onward
// to the dead-letter queue.
final jms:Session jmsUnmatchedSession = check createJmsSession(jmsConnection, jms:AUTO_ACKNOWLEDGE);

final jms:MessageProducer coreTransferUnmatchedProducer = check jmsUnmatchedSession.createProducer({
    'type: jms:QUEUE,
    name: "CORE.TRANSFER.UNMATCHED"
});

final jms:MessageProducer coreTransferDlqProducer = check jmsUnmatchedSession.createProducer({
    'type: jms:QUEUE,
    name: "CORE.TRANSFER.DLQ"
});

function createJmsSession(jms:Connection connection, jms:AcknowledgementMode ackMode) returns jms:Session|error {
    return connection->createSession(ackMode);
}
