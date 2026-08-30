# Represents an insurance claim submission.
public type ClaimSubmission record {|
    string claimId;
    string policyNumber;
    string claimType;
    decimal claimAmount;
    string incidentDate;
    string priority;
|};

# Represents the response returned after a claim is successfully published.
public type ClaimAccepted record {|
    string claimId;
    string routingKey;
|};

# Represents a claim message that exhausted its retries and landed on the dead-letter queue.
public type DeadLetterMessage record {|
    string claimId;
    string routingKey;
    int retryCount;
    string failureReason;
    ClaimSubmission claim;
|};

# Response body for the dead-letter drain/inspect endpoint.
public type DeadLetterListing record {|
    int count;
    DeadLetterMessage[] messages;
|};

# Response body returned after a replay request completes.
public type ReplayResult record {|
    int replayedCount;
    string[] claimIds;
|};

# Response body for the dead-letter stats endpoint, breaking queue depth down by claim type.
public type DeadLetterStats record {|
    int totalCount;
    map<int> countByClaimType;
|};

# Optional request body for the dead-letter replay endpoint.
public type ReplayRequest record {|
    string[] claimIds?;
|};

# Generic error message body used by error responses.
public type ErrorMessage record {|
    string message;
|};
