import ballerinax/activemq.driver as _;
import ballerinax/java.jms;

// Builds a message selector that restricts delivery to the configured instrument classes, e.g.
// instrumentClass IN ('EQUITY', 'FX').
function buildInstrumentClassSelector(string[] instrumentClasses) returns string {
    string[] quotedClasses = from string instrumentClass in instrumentClasses
        select string `'${instrumentClass}'`;
    string classList = string:'join(", ", ...quotedClasses);
    return string `instrumentClass IN (${classList})`;
}

final string instrumentClassSelector = buildInstrumentClassSelector(instrumentClasses);

// Non-durable subscription on MARKET.DATA.PRICES so this service can be scaled out horizontally:
// each instance gets its own independent subscription with no shared client id/subscriber name to
// coordinate. Ticks published while every instance is down are not retained by the broker.
listener jms:Listener marketDataPricesListener = check new (
    connectionConfig = {
        initialContextFactory: "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
        providerUrl: providerUrl
    },
    acknowledgementMode = jms:CLIENT_ACKNOWLEDGE,
    consumerOptions = {
        destination: {
            'type: jms:TOPIC,
            name: "MARKET.DATA.PRICES"
        },
        messageSelector: instrumentClassSelector
    }
);

final jms:Connection jmsPublishConnection = check new (
    initialContextFactory = "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
    providerUrl = providerUrl
);

// Session used to republish normalised ticks. Auto-acknowledge is sufficient here since these
// are outbound publishes rather than consumed messages.
final jms:Session jmsPublishSession = check createJmsPublishSession(jmsPublishConnection);

function createJmsPublishSession(jms:Connection connection) returns jms:Session|error {
    return connection->createSession(jms:AUTO_ACKNOWLEDGE);
}

final jms:MessageProducer normalisedTickProducer = check jmsPublishSession.createProducer({
    'type: jms:TOPIC,
    name: "MARKET.DATA.NORMALISED"
});
