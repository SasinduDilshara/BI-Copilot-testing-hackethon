import ballerina/http;
import ballerina/log;
import ballerina/tcp;

const string FIELD_SEPARATOR = "|";

service /trades on new http:Listener(9001) {

    resource function get .() returns TradeMessage[] {
        return getAllTrades();
    }

    resource function get [string tradeId]() returns TradeMessage|http:NotFound {
        TradeMessage? tradeMessage = getTrade(tradeId);
        if tradeMessage is () {
            return {
                body: string `trade not found for tradeId: ${tradeId}`
            };
        }
        return tradeMessage;
    }
}

service tcp:Service on new tcp:Listener(9090) {

    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService {
        log:printInfo("client connected", remoteHost = caller.remotePort);
        return new TradeConnectionService(caller);
    }
}

service class TradeConnectionService {
    *tcp:ConnectionService;

    private final tcp:Caller caller;

    function init(tcp:Caller caller) {
        self.caller = caller;
    }

    remote function onBytes(readonly & byte[] data) returns byte[]|tcp:Error? {
        string|error decodedMessage = string:fromBytes(data);
        if decodedMessage is error {
            log:printError("failed to decode incoming bytes", 'error = decodedMessage);
            return ();
        }

        TradeMessage|error tradeMessage = parseTradeMessage(decodedMessage);
        if tradeMessage is error {
            log:printError("failed to parse trade message", 'error = tradeMessage, rawMessage = decodedMessage);
            return ();
        }

        error? validationResult = validateTradeMessage(tradeMessage);
        string responseText;
        if validationResult is error {
            responseText = string `NACK${FIELD_SEPARATOR}${tradeMessage.tradeId}${FIELD_SEPARATOR}${validationResult.message()}`;
        } else {
            storeTrade(tradeMessage);
            forwardTradeToRiskEngine(tradeMessage);
            responseText = string `ACK${FIELD_SEPARATOR}${tradeMessage.tradeId}`;
        }

        tcp:Error? writeResult = self.caller->writeBytes(responseText.toBytes());
        if writeResult is tcp:Error {
            log:printError("failed to write response to caller", 'error = writeResult);
        }
        return ();
    }

    remote function onError(tcp:Error err) returns tcp:Error? {
        log:printError("tcp connection error", 'error = err);
    }

    remote function onClose() returns tcp:Error? {
        log:printInfo("connection closed", event = "connection_closed");
    }
}
