import ballerina/http;

// Claim submission accepted through the HTTP intake endpoint and sent to the
// claims-intake queue as a batch.
public type ClaimSubmission record {|
    string claimId;
    string policyNumber;
    string claimantId;
    decimal claimAmount;
    string incidentDate;
    string description?;
|};

// Batch of claim submissions accepted by the HTTP intake endpoint.
public type ClaimSubmissionBatch record {|
    ClaimSubmission[] claims;
|};

// Result produced after assessing a claim, published once the claim is accepted for
// further processing.
public type ClaimAssessmentResult record {|
    string claimId;
    string policyNumber;
    string decision;
    decimal assessedAmount;
    string reason;
    string assessedAt;
|};

// Response body confirming that a batch of claims was accepted for intake.
public type ClaimBatchAccepted record {|
    string message;
    int claimCount;
|};

// Response body describing a failure to submit a batch of claims.
public type ClaimBatchError record {|
    string message;
|};

public type ClaimBatchAcceptedResponse record {|
    *http:Accepted;
    ClaimBatchAccepted body;
|};

public type ClaimBatchErrorResponse record {|
    *http:InternalServerError;
    ClaimBatchError body;
|};

// Operational counters tracking how claims were settled by the assessment worker.
public type OperationalCounters record {|
    int completedCount;
    int deadLetteredCount;
    int abandonedCount;
|};

public type OperationalCountersResponse record {|
    *http:Ok;
    OperationalCounters body;
|};
