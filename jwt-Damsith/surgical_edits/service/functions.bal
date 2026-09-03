import ballerina/time;

// In-memory record of everything this forwarder has accepted, keyed by the
// claim id we hand back to the broker. Stands in for the claims table until
// the datastore work lands.
final map<ForwardedClaim> forwardedClaims = {};

// Source of the claim ids we mint. Brokers quote these back at us when they
// poll for status, so they have to stay stable for the life of the process.
int claimSequence = 4200;

// Mints the next broker-facing claim id.
function nextClaimId() returns string {
    claimSequence += 1;
    return "CLF-" + claimSequence.toString();
}

// Builds the record we keep for a claim we are about to forward.
function buildForwardedClaim(string claimId, ClaimSubmission submission, string submittedBy) returns ForwardedClaim {
    return {
        claimId: claimId,
        policyNumber: submission.policyNumber,
        incidentDate: submission.incidentDate,
        amount: submission.amount,
        description: submission.description,
        submittedBy: submittedBy,
        submittedAt: currentTimestamp(),
        status: "PENDING"
    };
}

// Maps a broker submission onto the payload shape the partner network wants.
function toPartnerRequest(string claimId, ClaimSubmission submission, string submittedBy) returns PartnerClaimRequest {
    return {
        sourceClaimId: claimId,
        policyNumber: submission.policyNumber,
        incidentDate: submission.incidentDate,
        amount: submission.amount,
        description: submission.description,
        originatingBroker: submittedBy
    };
}

// Records a claim once the partner network has acknowledged it.
function recordForwardedClaim(ForwardedClaim claim, PartnerAck ack) returns ForwardedClaim {
    ForwardedClaim stored = {
        claimId: claim.claimId,
        policyNumber: claim.policyNumber,
        incidentDate: claim.incidentDate,
        amount: claim.amount,
        description: claim.description,
        submittedBy: claim.submittedBy,
        submittedAt: claim.submittedAt,
        status: ack.status,
        partnerReference: ack.reference
    };
    forwardedClaims[stored.claimId] = stored;
    return stored;
}

// Looks up a claim this forwarder has previously accepted.
function getForwardedClaim(string claimId) returns ForwardedClaim? {
    return forwardedClaims[claimId];
}

// Refreshes a stored claim with the partner network's current view of it.
function refreshClaimStatus(ForwardedClaim claim, PartnerAck ack) returns ForwardedClaim {
    ForwardedClaim refreshed = {
        claimId: claim.claimId,
        policyNumber: claim.policyNumber,
        incidentDate: claim.incidentDate,
        amount: claim.amount,
        description: claim.description,
        submittedBy: claim.submittedBy,
        submittedAt: claim.submittedAt,
        status: ack.status,
        partnerReference: ack.reference
    };
    forwardedClaims[refreshed.claimId] = refreshed;
    return refreshed;
}

// Rejects submissions that are obviously unusable before we spend a partner
// call on them. Returns () when the submission looks sane.
function validateSubmission(ClaimSubmission submission) returns string? {
    if submission.policyNumber.trim().length() == 0 {
        return "policyNumber must not be empty";
    }
    if submission.amount <= 0d {
        return "amount must be greater than zero";
    }
    if submission.incidentDate.trim().length() == 0 {
        return "incidentDate must not be empty";
    }
    return ();
}

// Produces an ISO-8601 timestamp for the current instant.
function currentTimestamp() returns string {
    time:Utc now = time:utcNow();
    return time:utcToString(now);
}
