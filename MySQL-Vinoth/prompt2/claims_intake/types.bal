public type ClaimSubmission record {|
    string claimNumber;
    string policyNumber;
    string providerId;
    string diagnosisCode;
    decimal billedAmount;
    string serviceDate;
|};

public type AdjudicationRequest record {|
    string claimNumber;
    string policyNumber;
    string diagnosisCode;
    decimal billedAmount;
    decimal coverageLimit;
|};
