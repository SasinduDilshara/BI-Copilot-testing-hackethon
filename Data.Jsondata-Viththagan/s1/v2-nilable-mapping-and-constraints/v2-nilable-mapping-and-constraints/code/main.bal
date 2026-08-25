import ballerina/data.jsondata;
import ballerina/http;
import ballerina/log;

listener http:Listener orderFeedListener = new (8080);

service /orders on orderFeedListener {

    # Accepts a partner order feed payload in snake_case JSON, binds it into
    # strongly typed camelCase records (ignoring unmodeled metadata fields),
    # and acknowledges the mapped order.
    #
    # + payload - Raw JSON order feed payload sent by the partner
    # + return - Acknowledgement on success, or a bad request error if mapping fails
    resource function post feed(@http:Payload json payload) returns OrderFeedAck|http:BadRequest {
        jsondata:Options parseOptions = {
            allowDataProjection: {
                nilAsOptionalField: true,
                absentAsNilableType: true
            },
            enableConstraintValidation: true
        };
        OrderFeed|jsondata:Error orderFeed = jsondata:parseAsType(payload, parseOptions);
        if orderFeed is jsondata:Error {
            log:printError("Failed to map order feed payload", 'error = orderFeed);
            OrderFeedError errorBody = {message: "Invalid order feed payload: " + orderFeed.message()};
            return <http:BadRequest>{body: errorBody};
        }

        log:printInfo("Order feed accepted", orderId = orderFeed.orderId, customerEmail = orderFeed.customerEmail,
                lineItemCount = orderFeed.lineItems.length(), placedAt = orderFeed.placedAt);

        OrderFeedAck ack = {orderId: orderFeed.orderId, status: "ACCEPTED"};
        return ack;
    }
}
