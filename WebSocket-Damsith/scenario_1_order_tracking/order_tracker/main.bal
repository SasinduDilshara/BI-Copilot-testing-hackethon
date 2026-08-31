import ballerina/http;
import ballerina/jwt;
import ballerina/lang.runtime;
import ballerina/time;
import ballerina/websocket;

// Interval, in seconds, between simulated order status push updates.
final decimal updateIntervalSeconds = 5;

listener http:Listener secureHttpListener = new (servicePort, {
    secureSocket: {
        key: {
            certFile: tlsCertFile,
            keyFile: tlsKeyFile
        }
    }
});

listener websocket:Listener orderTrackingListener = new (secureHttpListener);

service /orders/track on orderTrackingListener {

    resource function get .(http:Request request, string? orderId) returns websocket:Service|websocket:UpgradeError {
        if orderId is () || orderId.trim().length() == 0 {
            return error websocket:UpgradeError("Missing required query parameter: orderId");
        }
        if !isKnownOrder(orderId) {
            return error websocket:UpgradeError(string `Unknown order ID: ${orderId}`);
        }
        string|websocket:UpgradeError authResult = authorizeOrderAccess(request, orderId);
        if authResult is websocket:UpgradeError {
            return authResult;
        }
        return new OrderTrackingService(orderId);
    }
}

// Validates the customer's JWT from the Authorization header and confirms the token's
// order claim matches the order being requested, so a customer can only track their own order.
isolated function authorizeOrderAccess(http:Request request, string orderId) returns string|websocket:UpgradeError {
    string authHeader;
    do {
        authHeader = check request.getHeader("Authorization");
    } on fail {
        return error websocket:UpgradeError("Missing required Authorization header");
    }
    if !authHeader.startsWith("Bearer ") {
        return error websocket:UpgradeError("Authorization header must be a Bearer token");
    }
    string bearerToken = authHeader.substring(7);

    jwt:ValidatorConfig validatorConfig = {
        issuer: jwtIssuer,
        audience: jwtAudience,
        signatureConfig: {
            certFile: jwtSigningCertFile
        }
    };
    jwt:Payload|jwt:Error validationResult = jwt:validate(bearerToken, validatorConfig);
    if validationResult is jwt:Error {
        return error websocket:UpgradeError("Invalid or expired JWT", validationResult);
    }

    // jwt:Payload is an open record, so application-specific claims are accessible via member access.
    anydata claimedOrderIdValue = validationResult[orderIdClaimName];
    if claimedOrderIdValue !is string {
        return error websocket:UpgradeError(string `JWT is missing the required '${orderIdClaimName}' claim`);
    }
    if claimedOrderIdValue != orderId {
        return error websocket:UpgradeError("This order does not belong to the authenticated customer");
    }
    return claimedOrderIdValue;
}

service /orders/dashboard on orderTrackingListener {

    resource function get .(http:Request request) returns websocket:Service|websocket:UpgradeError {
        return new DashboardStreamingService();
    }
}

service class OrderTrackingService {
    *websocket:Service;

    private final string orderId;
    private boolean active = true;

    isolated function init(string orderId) {
        self.orderId = orderId;
    }

    remote function onOpen(websocket:Caller caller) returns error? {
        Order? currentOrder = getOrder(self.orderId);
        if currentOrder is Order {
            readonly & OrderUpdate initialUpdate = buildOrderUpdate(currentOrder);
            check caller->writeMessage(initialUpdate);
        }
        worker StatusPusher {
            while self.isActive() {
                runtime:sleep(updateIntervalSeconds);
                if !self.isActive() {
                    break;
                }
                Order? updatedOrder = advanceOrder(self.orderId);
                if updatedOrder is Order {
                    readonly & OrderUpdate orderUpdate = buildOrderUpdate(updatedOrder);
                    websocket:Error? writeResult = caller->writeMessage(orderUpdate);
                    if writeResult is websocket:Error {
                        self.stop();
                    }
                    broadcastToDashboards(orderUpdate);
                    if updatedOrder.status == "DELIVERED" {
                        self.stop();
                    }
                } else {
                    self.stop();
                }
            }
        }
    }

    remote function onClose(websocket:Caller caller, int statusCode, string reason) {
        self.stop();
    }

    remote function onError(websocket:Caller caller, error err) {
        self.stop();
    }

    isolated function isActive() returns boolean {
        lock {
            return self.active;
        }
    }

    isolated function stop() {
        lock {
            self.active = false;
        }
    }
}

// Streams order updates for every active order to a single dashboard client.
// Reuses the same update-generation logic in OrderTrackingService; this class only
// manages the subscription lifecycle for the dashboard connection.
service class DashboardStreamingService {
    *websocket:Service;

    remote function onOpen(websocket:Caller caller) returns error? {
        addDashboardSubscriber(caller);
    }

    remote function onClose(websocket:Caller caller, int statusCode, string reason) {
        removeDashboardSubscriber(caller);
    }

    remote function onError(websocket:Caller caller, error err) {
        removeDashboardSubscriber(caller);
    }
}

// Builds the wire-format update message from the current order snapshot.
// This is the single source of update generation, shared by both the per-order
// tracking stream and the all-orders dashboard broadcast.
isolated function buildOrderUpdate(Order 'order) returns readonly & OrderUpdate {
    OrderUpdate orderUpdate = {
        orderId: 'order.orderId,
        status: 'order.status,
        courierLocation: 'order.courierLocation,
        estimatedArrival: 'order.estimatedArrival,
        updatedAt: time:utcToString(time:utcNow())
    };
    return orderUpdate.cloneReadOnly();
}
