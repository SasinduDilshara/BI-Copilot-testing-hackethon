import ballerinax/ibm.ibmmq;

// Builds a JMS-style message selector that restricts delivery to messages
// whose instrumentClass property is one of the configured instrument
// classes.
function buildInstrumentClassSelector(string[] configuredInstrumentClasses) returns string {
    string[] quotedInstrumentClasses = from string instrumentClass in configuredInstrumentClasses
        select string `'${instrumentClass}'`;
    string instrumentClassList = string:'join(", ", ...quotedInstrumentClasses);
    return string `instrumentClass IN (${instrumentClassList})`;
}

// Binds a raw IBM MQ message received on MARKET.DATA.PRICES to a typed
// PriceTick record. The upstream feed now sends UTF-8 text directly, so the
// payload bytes are decoded with the default UTF-8 decoding.
function mapToPriceTick(ibmmq:Message priceTickMessage) returns PriceTick|error {
    string payloadText = check string:fromBytes(priceTickMessage.payload);
    return payloadText.fromJsonStringWithType(PriceTick);
}

// Builds the market data stats response from the rolling per-instrument-class
// tick counts.
function mapToMarketDataStats(map<int> currentTickCounts) returns MarketDataStats {
    InstrumentClassTickCount[] instrumentClassCounts = from [string, int] [instrumentClass, tickCount] in currentTickCounts.entries()
        select {instrumentClass, tickCount};
    return {instrumentClassCounts};
}

