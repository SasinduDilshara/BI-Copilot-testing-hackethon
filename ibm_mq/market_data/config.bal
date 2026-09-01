// IBM MQ queue manager connection configurations.
configurable string queueManagerName = ?;
configurable string host = ?;
configurable int port = ?;
configurable string channel = ?;
configurable string userID = ?;
configurable string password = ?;

// TLS truststore holding the certificate(s) trusted for the IBM MQ server's
// TLS handshake. The cipher suite itself is not pinned here - the platform
// team manages TLS policy (protocol versions, ciphers) centrally.
configurable string truststorePath = ?;
configurable string truststorePassword = ?;

// Topic on which market data price ticks are published.
configurable string marketDataTopicName = "MARKET.DATA.PRICES";

// List of instrument classes this subscriber is interested in. Used to
// build a JMS message selector so the queue manager filters ticks before
// delivery.
configurable string[] instrumentClasses = ?;

// Interval, in seconds, the consumer waits between successive poll
// attempts when no message is immediately available.
configurable decimal pollingInterval = 5;

// Maximum time, in seconds, to wait for a message on each poll before
// giving up and retrying.
configurable decimal receiveTimeout = 10;

// HTTP listener port for the market data stats endpoint.
configurable int statsServicePort = 8081;

