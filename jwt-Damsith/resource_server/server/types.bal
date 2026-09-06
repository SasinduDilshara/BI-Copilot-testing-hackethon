// Claim status information returned to callers with claims:read scope.
public type ClaimStatus record {|
    string claimId;
    string status;
    string claimantName;
    decimal amount;
    string lastUpdated;
|};

// Summary view of a claim, used in listings.
public type ClaimSummary record {|
    string claimId;
    string status;
    string claimantName;
|};

// Result of a decision (approve/reject) made on a claim.
public type ClaimDecision record {|
    string claimId;
    string status;
    string decidedBy;
    string decidedAt;
|};

// Generic error payload returned to clients.
public type ErrorDetail record {|
    string message;
    string details?;
|};
