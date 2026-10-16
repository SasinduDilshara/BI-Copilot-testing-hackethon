// Partner API connection configurations.
configurable string partnerApiBaseUrl = ?;

// OAuth2 password grant configurations for the partner token endpoint.
configurable string tokenUrl = ?;
configurable string username = ?;
configurable string password = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string[] scopes = ?;

// Mutual TLS configurations for the token endpoint call (client keystore holding our
// certificate and private key, presented to the partner's token endpoint).
configurable string tokenEndpointKeystorePath = ?;
configurable string tokenEndpointKeystorePassword = ?;

// HTTP listener port for this service.
configurable int servicePort = 8080;
