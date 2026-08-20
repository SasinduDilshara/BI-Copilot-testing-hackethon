
public type Position record {|
    string positionId;
    string book;
    string instrumentId;
    decimal quantity;
    decimal markPrice;
|};

public type PositionReconciliationDlqEntry record {|
    string positionId;
    string book;
    string instrumentId;
    decimal quantity;
    decimal markPrice;
    string failureReason;
|};