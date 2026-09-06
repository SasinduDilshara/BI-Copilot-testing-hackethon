// HTTP listener port for the claims-forwarder API.
configurable int servicePort = 8080;

// Base URL of the partner claims network we forward accepted claims to.
configurable string partnerApiUrl = "https://claims.partner-net.example.com/v2";

// How long we wait on the partner network before giving up on a single call.
// The partner's own SLA is 20s at the 99th percentile, so anything under that
// just turns their slow days into our 5xx rate.
configurable decimal partnerApiTimeout = 30;

// Number of extra attempts for a forward that fails with a transport-level
// error. The partner network occasionally drops connections during their
// nightly window; retrying twice clears almost all of those.
configurable int maxForwardRetries = 2;

// Path to the public certificate used to verify the signature on bearer
// tokens issued by the broker portal's identity provider.
configurable string idpCertPath = ?;

// Expected issuer of a genuine bearer token. Tokens asserting any other
// issuer are rejected outright.
configurable string idpTokenIssuer = ?;

// Expected audience of a genuine bearer token, i.e. this service.
configurable string idpTokenAudience = ?;

// Path to our private key, registered with the partner network, used to sign
// the assertions we present to it in place of a long-lived shared token.
configurable string partnerSigningKeyPath = ?;

// Password protecting partnerSigningKeyPath, if the key file is encrypted.
configurable string partnerSigningKeyPassword = ?;

// Subject/issuer we assert ourselves as when signing a partner token. The
// partner network identifies us by this value.
configurable string partnerAssertionSubject = "claims-forwarder";

// Audience the partner network expects on a self-signed assertion.
configurable string partnerAssertionAudience = "claims-api";

// How long a self-signed assertion is valid for, in seconds, before the
// partner network will no longer accept it.
configurable decimal partnerAssertionValidity = 300;

// How long before expiry we mint a replacement assertion, in seconds. Wide
// enough that a slow request never straddles the token's death and starts
// collecting 401s from the partner network.
configurable decimal partnerAssertionRefreshMargin = 30;
