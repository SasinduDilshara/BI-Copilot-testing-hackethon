// Supported payment methods for an incoming order.
public enum PaymentMethod {
    CREDIT_CARD = "credit_card",
    PAYPAL = "paypal",
    CRYPTO = "crypto",
    BANK_TRANSFER = "bank_transfer"
}

// Suggested action recommended by the fraud analysis agent.
public enum SuggestedAction {
    RELEASE = "release",
    HOLD = "hold",
    ESCALATE_TO_FRAUD_TEAM = "escalate_to_fraud_team"
}

// Strongly typed order payload submitted for fraud analysis.
public type OrderRequest record {|
    string orderId;
    string customerId;
    decimal orderAmount;
    int itemCount;
    string shippingCountry;
    PaymentMethod paymentMethod;
|};

// Structured fraud analysis result produced by the orderFraudAgent.
public type FraudAnalysisResult record {|
    string orderId;
    boolean anomalyDetected;
    int riskScore;
    string anomalyType?;
    string analystGuidance;
    SuggestedAction suggestedAction;
|};

// Sanction status returned by the external sanctions-check API for a country.
public type SanctionStatus record {|
    string countryCode;
    boolean sanctioned;
|};
