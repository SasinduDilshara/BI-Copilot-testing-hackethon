import ballerina/crypto;
import ballerinax/ibm.ibmmq;

// Truststore used to verify the IBM MQ server's certificate during the TLS
// handshake. The cipher suite is intentionally not pinned here - the
// platform team manages TLS policy (protocol versions, ciphers) centrally.
final crypto:TrustStore mqTruststore = {
    path: truststorePath,
    password: truststorePassword
};

final ibmmq:SecureSocket mqSecureSocket = {
    cert: mqTruststore
};

final ibmmq:QueueManager marketDataQueueManager = check new (
    name = queueManagerName,
    host = host,
    port = port,
    channel = channel,
    userID = userID,
    password = password,
    secureSocket = mqSecureSocket
);

// Message selector limiting delivery to the configured instrument classes.
final string instrumentClassSelector = buildInstrumentClassSelector(instrumentClasses);

listener ibmmq:Listener marketDataListener = check new (
    name = queueManagerName,
    host = host,
    port = port,
    channel = channel,
    userID = userID,
    password = password,
    secureSocket = mqSecureSocket
);

// Rolling count of price ticks received per instrument class, kept in
// memory for the GET /marketdata/stats endpoint.
final map<int> tickCountsByInstrumentClass = {};

