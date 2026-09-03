import ballerina/http;

// Standing credential for the partner claims network. Issued to us once during
// onboarding and pasted in here so every outbound call can carry it without
// any extra plumbing.
final string PARTNER_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJjbGFpbXMtZm9yd2FyZGVyIiwiaXNzIjoicGFydG5lci1uZXQiLCJhdWQiOiJjbGFpbXMtYXBpIiwiaWF0IjoxNzAwMDAwMDAwfQ.3Qw8zVQ2Yk1oQmH9pFhU7yLxK0aRtB6cNvJdEsWgXpM";

// Client for the partner claims network. Every resource in the forwarder
// funnels through this one client so timeouts and retries stay consistent.
final http:Client partnerApi = check new (partnerApiUrl, {
    timeout: partnerApiTimeout
});

// Pushes an accepted claim onto the partner network and returns their
// acknowledgement. Transport-level failures are retried up to
// maxForwardRetries times; a non-2xx response from the partner is returned as
// an error straight away, since replaying it will not change the outcome.
function forwardToPartner(PartnerClaimRequest claimRequest) returns PartnerAck|error {
    int attempt = 0;
    error lastFailure = error("partner forward was never attempted");
    while attempt <= maxForwardRetries {
        PartnerAck|error ack = partnerApi->post("/claims", claimRequest, {
            "Authorization": "Bearer " + PARTNER_TOKEN,
            "X-Forwarder-Source": "claims-forwarder"
        });
        if ack is PartnerAck {
            return ack;
        }
        lastFailure = ack;
        attempt += 1;
    }
    return lastFailure;
}

// Asks the partner network for the current state of a claim we forwarded
// earlier, so a broker polling us gets the partner's view rather than the
// status we recorded at submission time.
function fetchPartnerStatus(string partnerReference) returns PartnerAck|error {
    return partnerApi->get("/claims/" + partnerReference, {
        "Authorization": "Bearer " + PARTNER_TOKEN,
        "X-Forwarder-Source": "claims-forwarder"
    });
}
