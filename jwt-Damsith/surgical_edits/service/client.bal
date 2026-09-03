import ballerina/http;
import ballerina/jwt;
import ballerina/time;

// Client for the partner claims network. Every resource in the forwarder
// funnels through this one client so timeouts and retries stay consistent.
final http:Client partnerApi = check new (partnerApiUrl, {
    timeout: partnerApiTimeout
});

// Holds the self-signed assertion we currently present to the partner
// network, alongside the instant it stops being safe to use. Replaces the
// old pasted-in constant: nothing long-lived is carried around any more, and
// rotation needs no redeploy since a fresh assertion is minted in-process.
type PartnerAssertion record {|
    string token;
    time:Utc validUntil;
|};

isolated (PartnerAssertion & readonly)? cachedAssertion = ();

// Signs a fresh short-lived assertion with our own private key - the key
// pair registered with the partner network - rather than carrying a
// long-lived shared token.
function mintPartnerAssertion() returns (PartnerAssertion & readonly)|error {
    jwt:IssuerConfig issuerConfig = {
        issuer: partnerAssertionSubject,
        username: partnerAssertionSubject,
        audience: partnerAssertionAudience,
        expTime: partnerAssertionValidity,
        signatureConfig: {
            config: {
                keyFile: partnerSigningKeyPath,
                keyPassword: partnerSigningKeyPassword
            }
        }
    };
    string token = check jwt:issue(issuerConfig);
    time:Utc validUntil = time:utcAddSeconds(time:utcNow(), partnerAssertionValidity);
    return {token, validUntil}.cloneReadOnly();
}

// Returns an assertion that is safe to use for at least
// partnerAssertionRefreshMargin more seconds, minting and caching a
// replacement ahead of expiry rather than waiting to be rejected first.
function getPartnerAssertion() returns string|error {
    (PartnerAssertion & readonly)? existing = ();
    lock {
        existing = cachedAssertion;
    }
    if existing is PartnerAssertion {
        time:Utc refreshBy = time:utcAddSeconds(existing.validUntil, -partnerAssertionRefreshMargin);
        if time:utcDiffSeconds(refreshBy, time:utcNow()) > 0d {
            return existing.token;
        }
    }

    PartnerAssertion & readonly fresh = check mintPartnerAssertion();
    lock {
        cachedAssertion = fresh;
    }
    return fresh.token;
}

// Pushes an accepted claim onto the partner network and returns their
// acknowledgement. Transport-level failures are retried up to
// maxForwardRetries times; a non-2xx response from the partner is returned as
// an error straight away, since replaying it will not change the outcome.
function forwardToPartner(PartnerClaimRequest claimRequest) returns PartnerAck|error {
    string assertion = check getPartnerAssertion();
    int attempt = 0;
    error lastFailure = error("partner forward was never attempted");
    while attempt <= maxForwardRetries {
        PartnerAck|error ack = partnerApi->post("/claims", claimRequest, {
            "Authorization": "Bearer " + assertion,
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
    string assertion = check getPartnerAssertion();
    return partnerApi->get("/claims/" + partnerReference, {
        "Authorization": "Bearer " + assertion,
        "X-Forwarder-Source": "claims-forwarder"
    });
}
