// Represents a market data price tick received on the MARKET.DATA.PRICES topic.
public type PriceTick record {|
    string instrumentId;
    string instrumentClass;
    decimal price;
    string currency;
    string timestamp;
|};

// Rolling tick count for a single instrument class.
public type InstrumentClassTickCount record {|
    string instrumentClass;
    int tickCount;
|};

// Response payload for GET /marketdata/stats.
public type MarketDataStats record {|
    InstrumentClassTickCount[] instrumentClassCounts;
|};

