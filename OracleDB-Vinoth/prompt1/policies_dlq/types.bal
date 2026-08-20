// Risk tier of the insurance policy application.
public type RiskTier "LOW"|"MEDIUM"|"HIGH";

# Incoming request to bind a new insurance policy.
public type PolicyBindRequest record {|
    string policyId;
    string customerId;
    decimal coverageAmount;
    RiskTier riskTier;
|};

# Premium breakdown mapped from the Oracle PREMIUM_BREAKDOWN_TYPE OBJECT result.
public type PremiumBreakdown record {|
    decimal baseAmount;
    decimal taxAmount;
    decimal brokerFee;
|};

# Response returned when a policy is successfully bound.
public type PolicyBoundResponse record {|
    string policyId;
    string customerId;
    decimal totalPremium;
    PremiumBreakdown premiumBreakdown;
|};

# Response returned when the bind operation could not be completed after retries,
# but the application was safely persisted to the dead letter queue.
public type PolicyQueuedResponse record {|
    string policyId;
    string message;
|};

# Generic error response payload.
public type ErrorResponse record {|
    string message;
|};
