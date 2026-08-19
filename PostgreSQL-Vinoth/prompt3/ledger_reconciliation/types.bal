
public type LedgerEntry record {|
    string entryId;
    string accountId;
    decimal amount;
    string entryType;
    string createdAt;
|};

# Represents a ledger_entries change event as delivered by CDC, excluding the
# account_holder_ssn column which must never be emitted in change events.
public type LedgerEntryChangeEvent record {|
    string entry_id;
    string account_id;
    decimal amount;
    string entry_type;
    string created_at;
    boolean reconciled;
|};