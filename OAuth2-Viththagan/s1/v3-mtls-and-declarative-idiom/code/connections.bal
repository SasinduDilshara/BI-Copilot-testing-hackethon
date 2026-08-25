import ballerina/crypto;
import ballerina/http;
import ballerina/oauth2;

// Client keystore used to present our certificate and private key to the partner's
// token endpoint for mutual TLS during OAuth2 token acquisition.
final crypto:KeyStore tokenEndpointKeyStore = {
    path: tokenEndpointKeystorePath,
    password: tokenEndpointKeystorePassword
};

// HTTP client for the partner REST API, secured with the OAuth2 password grant.
// The http:Client uses the built-in oauth2 password grant provider internally to obtain
// a short-lived access token from the partner's token endpoint, sending the client
// credentials in the POST body (not the Authorization header), and attaches the
// resulting token as a bearer token to every outbound request. When the token expires,
// it is automatically refreshed using the same token endpoint (inferred refresh config),
// and a clock skew allowance absorbs minor time differences between hosts so a
// still-valid token is not treated as expired prematurely. The call to the token
// endpoint itself is secured with mutual TLS using our client keystore.
// This is done declaratively through the http:Client's auth config rather than by
// calling the oauth2 client provider by hand, since http:Client accepts the OAuth2
// grant config directly and manages token retrieval, caching, and refresh internally.
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
        clockSkew: 10,
        clientConfig: {
            secureSocket: {
                key: tokenEndpointKeyStore
            }
        }
    }
});
