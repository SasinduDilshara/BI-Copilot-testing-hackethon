import ballerina/time;
import ballerina/xlsx;

# A single transaction line from the bank statement sheet.
public type StatementRow record {|
    @xlsx:Name {value: "Transaction ID"}
    string transactionId;
    @xlsx:Name {value: "Value Date"}
    time:Date valueDate;
    @xlsx:Name {value: "Description"}
    string description;
    @xlsx:Name {value: "Amount"}
    decimal amount;
    @xlsx:Name {value: "Balance"}
    decimal balance;
|};

# A posted entry from the internal ledger table.
public type LedgerRow record {|
    @xlsx:Name {value: "Entry ID"}
    string entryId;
    @xlsx:Name {value: "Txn Ref"}
    string txnRef;
    @xlsx:Name {value: "Posted Date"}
    time:Date postedDate;
    @xlsx:Name {value: "Amount"}
    decimal amount;
    @xlsx:Name {value: "Account"}
    string account;
|};

public type MismatchKind "MISSING_IN_LEDGER"|"MISSING_ON_STATEMENT"|"AMOUNT_MISMATCH";

# One reconciliation finding, written to the output report.
public type Mismatch record {|
    string txnRef;
    MismatchKind kind;
    decimal? statementAmount;
    decimal? ledgerAmount;
|};

# Metadata about a single reconciliation run, written to the 'Run Info' sheet.
public type RunInfo record {|
    string runTimestamp;
    string statementFile;
    int skippedRowCount;
|};
