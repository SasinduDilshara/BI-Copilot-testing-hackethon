import ballerina/http;
import ballerina/log;
import ballerinax/ibm.ibmmq;

// NOTE: This is a non-durable shared subscription (no subscriberName, so the
// queue manager does not keep a persistent subscription record). Multiple
// instances of this service can attach to the same subscription and share
// the delivered ticks, which is what lets the external load balancer scale
// this out horizontally. The trade-off: while every instance of this
// consumer is offline (or between the topic having zero subscribers and a
// new one attaching), ticks published during that gap are NOT retained by
// the queue manager and are NOT redelivered later - they are simply lost to
// this subscriber. A durable subscription would have retained them for
// redelivery on reconnect; a non-durable one will not.
@ibmmq:ServiceConfig {
    topicName: marketDataTopicName,
    consumerType: ibmmq:SHARED,
    sessionAckMode: ibmmq:CLIENT_ACKNOWLEDGE,
    messageSelector: instrumentClassSelector,
    pollingInterval: pollingInterval,
    receiveTimeout: receiveTimeout
}
service ibmmq:Service on marketDataListener {

    # Handles an incoming market data price tick delivered through the
    # non-durable shared subscription on MARKET.DATA.PRICES. The message is
    # acknowledged only after it has been successfully bound to a
    # PriceTick record and processed; if either step fails, the message is
    # left unacknowledged so it is redelivered.
    #
    # + message - the received IBM MQ message
    # + caller - the caller used to acknowledge the message
    # + return - an error if the acknowledgement itself fails
    remote function onMessage(ibmmq:Message message, ibmmq:Caller caller) returns error? {
        PriceTick|error priceTick = mapToPriceTick(message);
        if priceTick is error {
            log:printError("Failed to bind the price tick payload", priceTick);
            return;
        }

        error? processResult = processPriceTick(priceTick);
        if processResult is error {
            log:printError("Failed to process the price tick", processResult,
                    instrumentId = priceTick.instrumentId);
            return;
        }

        ibmmq:Error? acknowledgeResult = caller->acknowledge(message);
        if acknowledgeResult is ibmmq:Error {
            log:printError("Failed to acknowledge the price tick", acknowledgeResult,
                    instrumentId = priceTick.instrumentId);
            return acknowledgeResult;
        }

        recordTickForInstrumentClass(priceTick.instrumentClass);
        log:printInfo("Price tick acknowledged", instrumentId = priceTick.instrumentId);
    }

    # Handles runtime errors that occur while receiving or dispatching
    # messages from the MARKET.DATA.PRICES subscription.
    #
    # + mqError - the error encountered by the listener
    remote function onError(ibmmq:Error mqError) returns error? {
        log:printError("Error while receiving market data from IBM MQ", mqError);
    }
}

service /marketdata on new http:Listener(statsServicePort) {

    # Returns the rolling count of price ticks processed per instrument
    # class since this instance started.
    #
    # + return - the current per-instrument-class tick counts
    resource function get stats() returns MarketDataStats {
        lock {
            return mapToMarketDataStats(tickCountsByInstrumentClass.clone());
        }
    }
}

