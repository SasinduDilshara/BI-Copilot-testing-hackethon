import ballerina/http;
import ballerina/lang.runtime;
import ballerina/time;
import ballerina/websocket;

configurable int servicePort = 9090;

// Interval, in seconds, between simulated order status push updates.
final decimal updateIntervalSeconds = 5;

listener websocket:Listener orderTrackingListener = new (servicePort);

service /orders/track on orderTrackingListener {

    resource function get .(http:Request request, string? orderId) returns websocket:Service|websocket:UpgradeError {
        if orderId is () || orderId.trim().length() == 0 {
            return error websocket:UpgradeError("Missing required query parameter: orderId");
        }
        if !isKnownOrder(orderId) {
            return error websocket:UpgradeError(string `Unknown order ID: ${orderId}`);
        }
        return new OrderTrackingService(orderId);
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
            OrderUpdate initialUpdate = buildOrderUpdate(currentOrder);
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
                    OrderUpdate orderUpdate = buildOrderUpdate(updatedOrder);
                    websocket:Error? writeResult = caller->writeMessage(orderUpdate);
                    if writeResult is websocket:Error {
                        self.stop();
                    }
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

// Builds the wire-format update message from the current order snapshot.
isolated function buildOrderUpdate(Order 'order) returns OrderUpdate => {
    orderId: 'order.orderId,
    status: 'order.status,
    courierLocation: 'order.courierLocation,
    estimatedArrival: 'order.estimatedArrival,
    updatedAt: time:utcToString(time:utcNow())
};
