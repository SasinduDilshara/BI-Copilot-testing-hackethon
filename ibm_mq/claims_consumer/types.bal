// Represents an insurance claim submission received on the CLAIMS.INBOUND
// queue.
public type ClaimSubmission record {|
    string claimId;
    string policyNumber;
    string claimantName;
    decimal claimAmount;
    string incidentDate;
    string description;
|};

// Represents the audit entry written once a claim submission has been
// processed.
public type AuditEntry record {|
    string claimId;
    string status;
    string processedAt;
|};
