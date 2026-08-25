// Partner API connection configurations.
configurable string partnerApiBaseUrl = ?;

// OAuth2 client-credentials grant configurations for the partner token endpoint.
configurable string tokenUrl = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string[] scopes = ?;

// HTTP listener port for this service.
configurable int servicePort = 8080;
