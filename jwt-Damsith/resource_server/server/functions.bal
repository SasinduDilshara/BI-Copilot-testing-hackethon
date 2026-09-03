import ballerina/http;
import ballerina/jwt;
import ballerina/time;

// Extracts the subject (sub) claim from the caller's bearer token so
// approve/reject decisions can be attributed to the authenticated broker.
// The listener has already verified the token's signature, issuer, audience,
// and expiry before this resource executes; this only reads the payload.
function getCallerSubject(http:Request request) returns string|error {
    string authHeader = check request.getHeader("Authorization");
    string token = authHeader.startsWith("Bearer ") ? authHeader.substring(7) : authHeader;
    [jwt:Header, jwt:Payload] [_, payload] = check jwt:decode(token);
    string? subject = payload.sub;
    if subject is () {
        return "unknown-broker";
    }
    return subject;
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
