// Claim as it arrives from a broker's front-end.
public type ClaimSubmission record {|
    string policyNumber;
    string incidentDate;
    decimal amount;
    string description;
|};

// A claim we have accepted and forwarded on to the partner network.
// submittedBy is the caller identity taken from the inbound bearer token.
public type ForwardedClaim record {|
    string claimId;
    string policyNumber;
    string incidentDate;
    decimal amount;
    string description;
    string submittedBy;
    string submittedAt;
    string status;
    string partnerReference?;
|};

// Body we POST to the partner claims network.
public type PartnerClaimRequest record {|
    string sourceClaimId;
    string policyNumber;
    string incidentDate;
    decimal amount;
    string description;
    string originatingBroker;
|};

// What the partner network sends back when it accepts a claim.
public type PartnerAck record {|
    string reference;
    string status;
|};

// Acknowledgement returned to the broker once the claim is on its way.
public type ClaimAck record {|
    string claimId;
    string status;
    string partnerReference;
|};

// Generic error payload returned to clients.
public type ErrorDetail record {|
    string message;
    string details?;
|};
