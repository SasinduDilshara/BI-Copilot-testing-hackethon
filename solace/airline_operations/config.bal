// Solace PubSub+ broker connection configuration.
configurable string solaceBrokerUrl = ?;
configurable string solaceVpnName = ?;

// Authentication profile selection: "BASIC" or "OAUTH2".
configurable string authMode = "BASIC";

// Basic authentication credentials, used when authMode is "BASIC".
configurable string solaceUsername = ?;
configurable string solacePassword = ?;

// OAuth2 access token authentication, used when authMode is "OAUTH2".
configurable string solaceOAuth2Issuer = ?;
configurable string solaceOAuth2AccessToken = ?;

// TLS trust store configuration (validates the broker's certificate).
configurable string solaceTrustStoreLocation = ?;
configurable string solaceTrustStorePassword = ?;

// TLS key store configuration (presents a client certificate to the broker).
configurable string solaceKeyStoreLocation = ?;
configurable string solaceKeyStorePassword = ?;
configurable string solaceKeyPassword = ?;

// Common names trusted during TLS certificate validation.
configurable string[] solaceTrustedCommonNames = ?;

// Connection retry configuration.
configurable int solaceConnectRetries = 3;
configurable int solaceReconnectRetries = 5;
configurable decimal solaceReconnectRetryWait = 3.0;

// HTTP listener configuration.
configurable int servicePort = 8090;

// Disruption queue consumption configuration.
configurable string disruptionsQueueName = "AIRLINE.OPS.DISRUPTIONS";
configurable int disruptionsTransportWindowSize = 10;

// Passenger rebooking request-reply configuration.
configurable decimal rebookingReplyTimeout = 10.0;
