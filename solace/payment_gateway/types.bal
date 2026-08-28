import ballerina/http;
import ballerinax/solace;

# Represents a payment instruction submitted by a client.
#
# + instructionId - Unique identifier for the payment instruction
# + debtorIban - IBAN of the account the funds are debited from
# + creditorIban - IBAN of the account the funds are credited to
# + amount - Amount to be transferred
# + currency - ISO 4217 currency code of the amount
# + executionDate - Date on which the payment instruction should be executed
# + paymentScheme - Payment scheme/rail to use for processing the instruction
public type PaymentInstruction record {|
    string instructionId;
    string debtorIban;
    string creditorIban;
    decimal amount;
    string currency;
    string executionDate;
    string paymentScheme;
|};

# Represents an audit trail entry recorded for a payment instruction.
#
# + instructionId - Unique identifier of the audited payment instruction
# + debtorIban - IBAN of the account the funds are debited from
# + creditorIban - IBAN of the account the funds are credited to
# + amount - Amount to be transferred
# + currency - ISO 4217 currency code of the amount
# + executionDate - Date on which the payment instruction should be executed
# + paymentScheme - Payment scheme/rail used for processing the instruction
# + recordedTime - UTC timestamp at which the audit entry was recorded
public type AuditEntry record {|
    readonly string instructionId;
    string debtorIban;
    string creditorIban;
    decimal amount;
    string currency;
    string executionDate;
    string paymentScheme;
    string recordedTime;
|};

# Represents the confirmation returned after a payment instruction is committed.
#
# + instructionId - Unique identifier of the accepted payment instruction
# + topic - Destination queue the instruction was published to
public type PaymentInstructionAck record {|
    string instructionId;
    string queueName;
|};

# Represents the response returned when a payment instruction is accepted.
public type PaymentInstructionAccepted record {|
    *http:Created;
    PaymentInstructionAck body;
|};

# Represents an error detail payload.
#
# + message - Human readable error description
public type ErrorDetail record {|
    string message;
|};

# Represents the response returned when the request payload is invalid.
public type PaymentInstructionBadRequest record {|
    *http:BadRequest;
    ErrorDetail body;
|};

# Represents the response returned when the transacted publish and audit write could not both be
# completed, and the transaction was rolled back.
public type PaymentInstructionUnavailable record {|
    *http:ServiceUnavailable;
    ErrorDetail body;
|};

# Represents a payment instruction message consumed from `PAYMENTS.INSTRUCTIONS.IN`, narrowed so
# that the `PaymentInstruction` payload is data-bound directly instead of being delivered as raw
# `anydata`.
#
# + payload - The payment instruction carried by the message
public type PaymentInstructionMessage record {|
    *solace:Message;
    PaymentInstruction payload;
|};

# Represents a settled payment instruction published onto `PAYMENTS.SETTLEMENT.OUT`.
#
# + instructionId - Unique identifier of the settled payment instruction
# + debtorIban - IBAN of the account the funds are debited from
# + creditorIban - IBAN of the account the funds are credited to
# + amount - Amount to be transferred
# + currency - ISO 4217 currency code of the amount
# + executionDate - Date on which the payment instruction should be executed
# + paymentScheme - Payment scheme/rail used for processing the instruction
public type SettledPaymentInstruction record {|
    string instructionId;
    string debtorIban;
    string creditorIban;
    decimal amount;
    string currency;
    string executionDate;
    string paymentScheme;
|};

# Represents a non-retryable validation failure found while validating a payment instruction
# consumed from `PAYMENTS.INSTRUCTIONS.IN`. Instructions failing validation are routed to the dead
# letter queue rather than being redelivered.
public type ValidationError distinct error;
