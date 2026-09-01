import ballerina/log;

// Processes a received market data price tick. Any downstream processing
// failure is returned as an error so the caller can decide how to handle
// redelivery.
function processPriceTick(PriceTick priceTick) returns error? {
    log:printInfo("Processed price tick", instrumentId = priceTick.instrumentId,
            instrumentClass = priceTick.instrumentClass, price = priceTick.price,
            currency = priceTick.currency, timestamp = priceTick.timestamp);
}

// Increments the rolling tick count kept for the price tick's instrument
// class, used to serve GET /marketdata/stats.
function recordTickForInstrumentClass(string instrumentClass) {
    lock {
        int currentTickCount = tickCountsByInstrumentClass[instrumentClass] ?: 0;
        tickCountsByInstrumentClass[instrumentClass] = currentTickCount + 1;
    }
}

