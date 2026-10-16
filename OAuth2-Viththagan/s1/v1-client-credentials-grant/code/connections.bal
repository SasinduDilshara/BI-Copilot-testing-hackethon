import ballerina/http;

// HTTP client for the partner REST API, secured with the OAuth2 client-credentials grant.
// The http:Client uses the built-in oauth2 client credentials provider internally to obtain
// an access token from the partner's token endpoint and attaches it as a bearer token to
// every outbound request, refreshing it automatically when it expires.
final http:Client partnerApiClient = check new (partnerApiBaseUrl, {
    auth: {
        tokenUrl: tokenUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: scopes
    }
});
