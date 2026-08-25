import ballerina/log;
import ballerina/ftp;

// Processes a single, strongly typed partner order and executes downstream
// business logic for it.
function processOrder(Order 'order) returns error? {
    log:printInfo("Processing partner order", orderId = 'order.orderId, customerId = 'order.customerId,
            productCode = 'order.productCode, quantity = 'order.quantity);
}
