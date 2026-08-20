
public type Position record {|
    string positionId;
    string book;
    string instrumentId;
    decimal quantity;
    decimal markPrice;
    string? tradeNotes;
|};

public type PositionReconciliationDlqEntry record {|
    string positionId;
    string book;
    string instrumentId;
    decimal quantity;
    decimal markPrice;
    string? tradeNotes;
    string failureReason;
|};