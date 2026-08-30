import ballerinax/activemq.driver as _;
import ballerinax/java.jms;

// Listener bound to the SHIPMENT.STATUS.IN queue. The consuming service is configured with
// client acknowledgement mode so messages are only removed once they have either been processed
// successfully or forwarded to the dead-letter queue.
listener jms:Listener shipmentStatusListener = check new (
    connectionConfig = {
        initialContextFactory: "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
        providerUrl: providerUrl
    },
    acknowledgementMode = jms:CLIENT_ACKNOWLEDGE,
    consumerOptions = {
        destination: {
            'type: jms:QUEUE,
            name: shipmentStatusInQueue
        }
    }
);

// Separate connection and session used to publish messages that fail JSON binding onward to
// SHIPMENT.STATUS.DLQ, and to publish accepted/exception events to their routed queues.
final jms:Connection shipmentStatusPublishConnection = check new (
    initialContextFactory = "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
    providerUrl = providerUrl
);

final jms:Session shipmentStatusPublishSession = check createJmsSession(shipmentStatusPublishConnection, jms:AUTO_ACKNOWLEDGE);

final jms:MessageProducer shipmentStatusDlqProducer = check shipmentStatusPublishSession.createProducer({
    'type: jms:QUEUE,
    name: shipmentStatusDlqQueue
});

// Unbound producer used with sendTo() to publish accepted and exception events to whichever
// queue carrier-based routing resolves to.
final jms:MessageProducer shipmentStatusRoutedProducer = check shipmentStatusPublishSession.createProducer();

function createJmsSession(jms:Connection connection, jms:AcknowledgementMode ackMode) returns jms:Session|error {
    return connection->createSession(ackMode);
}
