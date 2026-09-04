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
    // Artificial delay applied during scoring to simulate an assessment that runs
    // longer than the queue's lock duration, used to exercise lock renewal.
    int simulatedProcessingDelaySeconds?;
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
    int lockRenewalFailedCount;
    int deferredCount;
|};

public type OperationalCountersResponse record {|
    *http:Ok;
    OperationalCounters body;
|};

// Metadata about a claim deferred for manual review, keyed by its Service Bus sequence
// number so it can be retrieved later via the deferred-claims endpoint.
public type DeferredClaim record {|
    int sequenceNumber;
    string claimId;
    string policyNumber;
    decimal claimAmount;
    string deferredAt;
|};

public type DeferredClaimsResponse record {|
    *http:Ok;
    DeferredClaim[] body;
|};

public type ClaimAssessmentResultResponse record {|
    *http:Ok;
    ClaimAssessmentResult body;
|};

public type DeferredClaimNotFoundResponse record {|
    *http:NotFound;
    ClaimBatchError body;
|};
