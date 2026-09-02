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

// Token lifetime in seconds, sized for a single shift.
configurable decimal tokenExpiryInSeconds = 43200;

// HTTP listener port for the issuing service.
configurable int servicePort = 8080;
