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

// Name of the JWT claim that carries this caller's entitlements/scopes.
// Our Keycloak realm publishes these under a non-standard, flat claim
// (not the OAuth2-standard "scope" claim), via a custom protocol mapper.
// This must match that mapper's claim name exactly.
configurable string idpScopeClaim = "entitlements";

// How long fetched JWKS keys are held in memory before Keycloak is called
// again. This is the main lever against hammering the IdP: every inbound
// request that hits an unpopulated/expired cache triggers a JWKS fetch, so a
// too-short TTL reproduces the "one call per request" problem, while a too-long
// TTL means a genuine key rotation on the IdP side goes unnoticed until this
// value elapses (there is no pod restart involved either way — the cache is
// just in-memory state that expires on its own).
// 5 minutes is a reasonable middle ground: it cuts IdP calls drastically
// under load while still picking up a rotated key well within the same shift.
configurable decimal jwksCacheTtlSeconds = 300;

// Explicit tolerance for clock drift between our pods and the IdP when
// checking token expiry/not-before. Kept as an explicit, ops-visible setting
// rather than relying on the JWT validator's implicit default.
configurable decimal jwtClockSkewSeconds = 60;

// HTTP listener port for the claims-processing API.
configurable int servicePort = 9090;
