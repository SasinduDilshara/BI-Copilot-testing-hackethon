// Parses a pipe-delimited trade message string into a TradeMessage record.
// Format: tradeId|symbol|side|quantity|price|brokerId
function parseTradeMessage(string message) returns TradeMessage|error {
    string[] fields = re `\|`.split(message);
    if fields.length() != 6 {
        return error("invalid message format, expected 6 fields");
    }

    string tradeId = fields[0];
    string symbol = fields[1];
    string side = fields[2];
    int quantity = check int:fromString(fields[3]);
    decimal price = check decimal:fromString(fields[4]);
    string brokerId = fields[5];

    TradeMessage tradeMessage = {
        tradeId,
        symbol,
        side,
        quantity,
        price,
        brokerId
    };
    return tradeMessage;
}

// Validates the business rules for a trade message. Returns an error with the reason on failure.
function validateTradeMessage(TradeMessage tradeMessage) returns error? {
    if tradeMessage.quantity <= 0 {
        return error("quantity must be greater than 0");
    }
    if tradeMessage.price <= 0.0d {
        return error("price must be greater than 0");
    }
    if tradeMessage.symbol.trim().length() == 0 {
        return error("symbol must not be empty");
    }
    return ();
}

// Stores the trade in the in-memory map keyed by tradeId.
isolated function storeTrade(TradeMessage tradeMessage) {
    lock {
        tradeStore[tradeMessage.tradeId] = tradeMessage.clone();
    }
}

// Retrieves all stored trades.
isolated function getAllTrades() returns TradeMessage[] {
    lock {
        return tradeStore.toArray().clone();
    }
}

// Retrieves a specific trade by tradeId.
isolated function getTrade(string tradeId) returns TradeMessage? {
    lock {
        TradeMessage? tradeMessage = tradeStore[tradeId];
        return tradeMessage.clone();
    }
}
