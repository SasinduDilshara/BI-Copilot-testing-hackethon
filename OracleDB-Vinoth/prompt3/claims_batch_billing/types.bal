
public type ClaimLine record {|
    string claimLineId;
    string claimId;
    string procedureCode;
    decimal billedAmount;
|};

public type DeadLetterClaimLine record {|
    *ClaimLine;
    string failureReason;
|};

public type PendingClaimLinesPage record {|
    ClaimLine[] items;
    string? nextPageToken;
|};