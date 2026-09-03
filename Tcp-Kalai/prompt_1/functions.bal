import ballerina/log;
import ballerina/tcp;

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

// Updates the riskStatus field of a previously stored trade.
isolated function updateTradeRiskStatus(string tradeId, string riskStatus) {
    lock {
        TradeMessage? tradeMessage = tradeStore[tradeId];
        if tradeMessage is TradeMessage {
            tradeMessage.riskStatus = riskStatus;
            tradeStore[tradeId] = tradeMessage;
        }
    }
}

// Serializes a trade message back into the pipe-delimited wire format.
function serializeTradeMessage(TradeMessage tradeMessage) returns string {
    return string `${tradeMessage.tradeId}${FIELD_SEPARATOR}${tradeMessage.symbol}${FIELD_SEPARATOR}${tradeMessage.side}${FIELD_SEPARATOR}${tradeMessage.quantity}${FIELD_SEPARATOR}${tradeMessage.price}${FIELD_SEPARATOR}${tradeMessage.brokerId}`;
}

// Forwards a validated trade to the downstream risk management system and records its risk status.
// Connection failures are logged and do not propagate, so the broker ACK is never blocked.
function forwardTradeToRiskEngine(TradeMessage tradeMessage) {
    tcp:Client|tcp:Error riskEngineClient = new (riskEngineHost, riskEnginePort);
    if riskEngineClient is tcp:Error {
        log:printError("failed to connect to risk engine", 'error = riskEngineClient, tradeId = tradeMessage.tradeId);
        return;
    }

    string serializedTrade = serializeTradeMessage(tradeMessage);
    tcp:Error? writeResult = riskEngineClient->writeBytes(serializedTrade.toBytes());
    if writeResult is tcp:Error {
        log:printError("failed to write trade to risk engine", 'error = writeResult, tradeId = tradeMessage.tradeId);
        tcp:Error? closeResult = riskEngineClient->close();
        if closeResult is tcp:Error {
            log:printError("failed to close risk engine connection", 'error = closeResult, tradeId = tradeMessage.tradeId);
        }
        return;
    }

    byte[]&readonly|tcp:Error readResult = riskEngineClient->readBytes();
    if readResult is tcp:Error {
        log:printError("failed to read response from risk engine", 'error = readResult, tradeId = tradeMessage.tradeId);
        tcp:Error? closeResult = riskEngineClient->close();
        if closeResult is tcp:Error {
            log:printError("failed to close risk engine connection", 'error = closeResult, tradeId = tradeMessage.tradeId);
        }
        return;
    }

    string|error riskResponse = string:fromBytes(readResult);
    if riskResponse is error {
        log:printError("failed to decode risk engine response", 'error = riskResponse, tradeId = tradeMessage.tradeId);
    } else {
        updateTradeRiskStatus(tradeMessage.tradeId, riskResponse);
    }

    tcp:Error? closeResult = riskEngineClient->close();
    if closeResult is tcp:Error {
        log:printError("failed to close risk engine connection", 'error = closeResult, tradeId = tradeMessage.tradeId);
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
