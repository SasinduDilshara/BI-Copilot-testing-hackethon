// Converts a price tick into the map content used for the MARKET.DATA.NORMALISED map message.
function toNormalisedTickContent(PriceTick priceTick) returns map<anydata> => {
    instrumentId: priceTick.instrumentId,
    instrumentClass: priceTick.instrumentClass,
    bid: priceTick.bid,
    ask: priceTick.ask,
    lastTradedPrice: priceTick.lastTradedPrice,
    volume: priceTick.volume,
    tickTime: priceTick.tickTime
};
