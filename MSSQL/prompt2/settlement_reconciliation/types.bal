
public type SettlementRecord record {|
    string settlementId;
    string storeId;
    decimal amount;
    string batchDate;
|};

# A settlement record that could not be inserted after all retries were exhausted,
# together with the reason it kept failing.
public type FailedSettlementRecord record {|
    *SettlementRecord;
    string failureReason;
|};