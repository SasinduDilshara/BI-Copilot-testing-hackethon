import ballerina/http;
import ballerina/log;
import ballerinax/java.jms;

listener http:Listener marketDataControlListener = new (servicePort);

// A named service value (rather than an inline service-on-listener) so it can be dynamically
// detached/attached to marketDataPricesListener for the pause/resume endpoints.
jms:Service marketDataPricesConsumerService = service object {

    // Processes an inbound price tick and acknowledges it only after processing succeeds, so a
    // failure leaves the message unacknowledged and eligible for redelivery.
    remote function onMessage(jms:Message message, jms:Caller caller) returns error? {
        return handlePriceTickMessage(message, caller);
    }
};

function handlePriceTickMessage(jms:Message message, jms:Caller caller) returns error? {
    if message !is jms:TextMessage {
        log:printWarn("Received non-text message on MARKET.DATA.PRICES, skipping");
        return;
    }

    PriceTick|error priceTick = message.content.fromJsonStringWithType(PriceTick);
    if priceTick is error {
        log:printError("Failed to parse price tick payload", 'error = priceTick);
        return;
    }

    processPriceTick(priceTick);
    tickCounter.increment(priceTick.instrumentClass);
    check publishNormalisedTick(priceTick);

    check caller->acknowledge(message);
}

// Handles a single price tick. Replace with the actual downstream processing logic.
function processPriceTick(PriceTick priceTick) {
    log:printInfo("Price tick processed",
            instrumentId = priceTick.instrumentId,
            instrumentClass = priceTick.instrumentClass,
            lastTradedPrice = priceTick.lastTradedPrice);
}

// Explicitly attaches the consumer service to the listener at startup, instead of the
// declarative `service on listener` syntax, so it can later be dynamically detached/re-attached
// by the pause/resume endpoints below.
function init() returns error? {
    check marketDataPricesListener.attach(marketDataPricesConsumerService, "market-data-prices-consumer");
    check marketDataPricesListener.'start();
}

service /marketdata on marketDataControlListener {

    # Pauses consumption from MARKET.DATA.PRICES by detaching the consumer service. Since the
    # subscription is non-durable, ticks published while paused (or while every instance is down)
    # are not retained by the broker and will be missed.
    #
    # + return - Confirmation that consumption has been paused, or an error response
    resource function post pause() returns ControlResponse|http:InternalServerError {
        if !consumerState.isAttached() {
            return {state: "PAUSED", message: "Consumption is already paused"};
        }

        error? detachResult = marketDataPricesListener.detach(marketDataPricesConsumerService);
        if detachResult is error {
            return {
                body: {
                    message: "Failed to pause consumption: " + detachResult.message()
                }
            };
        }
        consumerState.markDetached();
        return {state: "PAUSED", message: "Consumption from MARKET.DATA.PRICES has been paused"};
    }

    # Resumes consumption from MARKET.DATA.PRICES by re-attaching the consumer service.
    #
    # + return - Confirmation that consumption has resumed, or an error response
    resource function post resume() returns ControlResponse|http:InternalServerError {
        if consumerState.isAttached() {
            return {state: "RUNNING", message: "Consumption is already running"};
        }

        error? attachResult = marketDataPricesListener.attach(marketDataPricesConsumerService,
                "market-data-prices-consumer");
        if attachResult is error {
            return {
                body: {
                    message: "Failed to resume consumption: " + attachResult.message()
                }
            };
        }
        consumerState.markAttached();
        return {state: "RUNNING", message: "Consumption from MARKET.DATA.PRICES has resumed"};
    }

    # Returns a running count of ticks processed so far, broken down by instrument class.
    #
    # + return - The running tick counts by instrument class
    resource function get stats() returns TickStats {
        return {countsByInstrumentClass: tickCounter.snapshot()};
    }
}
