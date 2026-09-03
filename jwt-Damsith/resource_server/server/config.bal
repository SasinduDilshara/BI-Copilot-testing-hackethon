// Corporate IdP (Keycloak) JWT validation configuration.
// The IdP's signing keys are never shipped with the build — they are fetched
// live from Keycloak's realm certificate (JWKS) endpoint and cached in memory
// at runtime, so key rotation on the Keycloak side needs no redeploy here.
//
// Current Keycloak release (26.7.x, per https://www.keycloak.org/securing-apps/oidc-layers)
// exposes the JWKS endpoint at:
//   /realms/{realm-name}/protocol/openid-connect/certs
// There is no "/auth/" prefix on this path — that prefix was dropped in
// Keycloak 17 (Quarkus distribution) and only appears in outdated tutorials.
// idpBaseUrl should be the Keycloak server root, e.g. "https://idp.example.com",
// and idpRealm the realm name, e.g. "broker-partners".
configurable string idpBaseUrl = ?;
configurable string idpRealm = ?;
configurable string idpAudience = ?;

// HTTP listener port for the claims-processing API.
configurable int servicePort = 9090;
