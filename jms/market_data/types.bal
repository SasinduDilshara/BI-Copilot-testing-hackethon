// Market data price tick received from the MARKET.DATA.PRICES topic.
public type PriceTick record {|
    string instrumentId;
    string instrumentClass;
    decimal bid;
    decimal ask;
    decimal lastTradedPrice;
    decimal volume;
    string tickTime;
|};

// Response confirming a pause/resume control operation.
public type ControlResponse record {|
    string state;
    string message;
|};

// Running count of ticks processed for a single instrument class.
public type InstrumentClassTickCount record {|
    string instrumentClass;
    int tickCount;
|};

// Running tick counts across all instrument classes seen so far, returned by GET /marketdata/stats.
public type TickStats record {|
    InstrumentClassTickCount[] countsByInstrumentClass;
|};
