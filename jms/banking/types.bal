// Request payload for initiating a core-banking transfer.
public type TransferRequest record {|
    string transferId;
    string debitAccount;
    string creditAccount;
    decimal amount;
    string currency;
    string valueDate;
|};

// Response returned once the transfer request has been accepted for processing.
public type TransferAccepted record {|
    string transferId;
    string status;
|};

// Tracks the lifecycle of a transfer request awaiting a core-banking response.
public type PendingTransferStatus "PENDING"|"COMPLETED"|"FAILED";

public type PendingTransfer record {|
    string transferId;
    PendingTransferStatus status;
    string? coreStatus;
    string? coreMessage;
|};
