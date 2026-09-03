import ballerina/http;
import ballerina/jwt;
import ballerina/time;

// Pulls the raw bearer token out of the Authorization header. The listener
// has already verified this token's signature, issuer, audience, and expiry
// before any resource runs; everything below only reads its payload.
function extractBearerToken(http:Request request) returns string|error {
    string authHeader = check request.getHeader("Authorization");
    return authHeader.startsWith("Bearer ") ? authHeader.substring(7) : authHeader;
}

// Extracts the subject (sub) claim from the caller's bearer token so
// approve/reject decisions can be attributed to the authenticated broker.
function getCallerSubject(http:Request request) returns string|error {
    string token = check extractBearerToken(request);
    [jwt:Header, jwt:Payload] [_, payload] = check jwt:decode(token);
    string? subject = payload.sub;
    if subject is () {
        return "unknown-broker";
    }
    return subject;
}

// Enforces that the caller's token carries the required entitlement.
// Our IdP publishes entitlements under a non-standard, flat claim
// (idpScopeClaim, e.g. "entitlements") rather than the OAuth2-standard
// "scope" claim, as a space-delimited string of granted scope values.
// Returns () when the caller is entitled, or a Forbidden response in our
// standard error body shape otherwise - callers must check the result and
// return it immediately when it is not ().
function requireScope(http:Request request, string requiredScope) returns http:Forbidden? {
    string|error token = extractBearerToken(request);
    if token is error {
        ErrorDetail forbiddenDetail = {message: "Missing or invalid bearer token"};
        return <http:Forbidden>{body: forbiddenDetail};
    }
    [jwt:Header, jwt:Payload]|jwt:Error decoded = jwt:decode(token);
    if decoded is jwt:Error {
        ErrorDetail forbiddenDetail = {message: "Unable to read caller entitlements"};
        return <http:Forbidden>{body: forbiddenDetail};
    }
    [jwt:Header, jwt:Payload] [_, payload] = decoded;
    anydata scopeClaimValue = payload[idpScopeClaim];
    string[] grantedScopes = [];
    if scopeClaimValue is string {
        grantedScopes = re `\s+`.split(scopeClaimValue.trim());
    } else if scopeClaimValue is string[] {
        grantedScopes = scopeClaimValue;
    }
    if grantedScopes.indexOf(requiredScope) is () {
        ErrorDetail forbiddenDetail = {
            message: "Caller is not entitled to perform this operation",
            details: string `Missing required entitlement: ${requiredScope}`
        };
        return <http:Forbidden>{body: forbiddenDetail};
    }
    return ();
}

// In-memory claims store acting as the backing data source for the API.
final map<ClaimStatus> claimsStore = {
    "CLM-1001": {
        claimId: "CLM-1001",
        status: "PENDING",
        claimantName: "Alice Perera",
        amount: 2500.00,
        lastUpdated: "2026-09-01T10:00:00Z"
    },
    "CLM-1002": {
        claimId: "CLM-1002",
        status: "PENDING",
        claimantName: "Nimal Silva",
        amount: 8200.50,
        lastUpdated: "2026-09-02T14:30:00Z"
    }
};

// Returns a summary list of all claims.
function getAllClaimSummaries() returns ClaimSummary[] {
    return from ClaimStatus claim in claimsStore
        select {claimId: claim.claimId, status: claim.status, claimantName: claim.claimantName};
}

// Retrieves the full status of a single claim by its identifier.
function getClaimById(string claimId) returns ClaimStatus? {
    return claimsStore[claimId];
}

// Approves a pending claim and records the decision.
function approveClaimById(string claimId, string decidedBy) returns ClaimDecision? {
    ClaimStatus? claim = claimsStore[claimId];
    if claim is () {
        return ();
    }
    string decidedAt = getCurrentTimestamp();
    ClaimStatus updatedClaim = {claimId: claim.claimId, status: "APPROVED", claimantName: claim.claimantName, amount: claim.amount, lastUpdated: decidedAt};
    claimsStore[claimId] = updatedClaim;
    return {claimId: claimId, status: "APPROVED", decidedBy: decidedBy, decidedAt: decidedAt};
}

// Rejects a pending claim and records the decision.
function rejectClaimById(string claimId, string decidedBy) returns ClaimDecision? {
    ClaimStatus? claim = claimsStore[claimId];
    if claim is () {
        return ();
    }
    string decidedAt = getCurrentTimestamp();
    ClaimStatus updatedClaim = {claimId: claim.claimId, status: "REJECTED", claimantName: claim.claimantName, amount: claim.amount, lastUpdated: decidedAt};
    claimsStore[claimId] = updatedClaim;
    return {claimId: claimId, status: "REJECTED", decidedBy: decidedBy, decidedAt: decidedAt};
}

// Produces an ISO-8601 timestamp for the current instant.
function getCurrentTimestamp() returns string {
    time:Utc now = time:utcNow();
    return time:utcToString(now);
}
