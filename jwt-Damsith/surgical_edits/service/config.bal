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
