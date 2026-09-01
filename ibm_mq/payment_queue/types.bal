// Represents a payment instruction submitted by a client to be placed on the
// PAYMENT.INSTRUCTIONS queue.
public type PaymentInstruction record {|
    string instructionId;
    string debtorAccount;
    string creditorAccount;
    decimal amount;
    string currency;
    string scheme;
    string originatingBranch;
    string? remittanceInformation;
|};

// Generic error response payload.
public type ErrorDetails record {|
    string message;
    int? reasonCode;
    string timestamp;
|};

// Represents a payment response read back from PAYMENT.RESPONSES for the
// originating request.
public type PaymentResponse record {|
    string instructionId;
    string correlationId;
    string status;
|};
