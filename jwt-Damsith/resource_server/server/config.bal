// Corporate IdP JWT validation configuration.
// The IdP's signing keys are never shipped with the build — they are fetched
// live from the IdP's JWKS endpoint and cached in memory at runtime.
configurable string idpJwksUrl = ?;
configurable string idpIssuer = ?;
configurable string idpAudience = ?;

// HTTP listener port for the claims-processing API.
configurable int servicePort = 9090;
