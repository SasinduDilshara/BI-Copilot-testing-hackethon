import ballerina/log;

// Processes a single, strongly typed partner order and executes downstream
// business logic for it.
function processOrder(Order 'order) returns error? {
    log:printInfo("Processing partner order", orderId = 'order.orderId, customerId = 'order.customerId,
            productCode = 'order.productCode, quantity = 'order.quantity);
}

// Processes a single, strongly typed partner return and executes downstream
// business logic for it.
function processReturn(Return partnerReturn) returns error? {
    log:printInfo("Processing partner return", returnId = partnerReturn.returnId, orderId = partnerReturn.orderId,
            productCode = partnerReturn.productCode, quantity = partnerReturn.quantity);
}
