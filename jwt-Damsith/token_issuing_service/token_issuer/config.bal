// Base URL of the existing driver credentials store service.
configurable string credentialsStoreBaseUrl = ?;

// PKCS#12 keystore issued by the PKI team, used to sign driver tokens.
configurable string keystorePath = ?;
configurable string keystorePassword = ?;
configurable string keystoreKeyAlias = ?;
configurable string keystoreKeyPassword = ?;

// JWT issuance settings.
configurable string tokenIssuer = "driver-tracking-token-issuer";
configurable string tokenAudience = "driver-tracking-downstream-services";

// Region this issuer instance serves, e.g. "colombo", "jakarta". Embedded in the token
// audience so a token minted for one region is rejected by services validating against
// another region's audience, without any downstream lookup.
configurable string tokenRegion = ?;

// Token lifetime in seconds, sized for a single shift.
configurable decimal tokenExpiryInSeconds = 43200;

// HTTP listener port for the issuing service.
configurable int servicePort = 8080;
