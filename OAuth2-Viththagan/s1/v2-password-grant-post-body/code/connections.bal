import ballerina/http;
import ballerina/oauth2;

// HTTP client for the partner REST API, secured with the OAuth2 password grant.
// The http:Client uses the built-in oauth2 password grant provider internally to obtain
// a short-lived access token from the partner's token endpoint, sending the client
// credentials in the POST body (not the Authorization header), and attaches the
// resulting token as a bearer token to every outbound request. When the token expires,
// it is automatically refreshed using the same token endpoint (inferred refresh config),
// and a clock skew allowance absorbs minor time differences between hosts so a
// still-valid token is not treated as expired prematurely.
final http:Client partnerApiClient = check new (partnerApiBaseUrl, {
    auth: {
        tokenUrl: tokenUrl,
        username: username,
        password: password,
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: scopes,
        credentialBearer: oauth2:POST_BODY_BEARER,
        refreshConfig: "INFER_REFRESH_CONFIG",
        clockSkew: 10
    }
});
