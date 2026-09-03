// Represents a parsed trade execution message.
public type TradeMessage record {|
    string tradeId;
    string symbol;
    string side;
    int quantity;
    decimal price;
    string brokerId;
    string riskStatus?;
|};
