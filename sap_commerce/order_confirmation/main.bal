import ballerina/http;
import ballerina/log;
import ballerinax/sap.commerce.webservices as sapcommerce;

service /orders on new http:Listener(listenerPort) {

    // Accepts the newly created SAP Commerce order id, retrieves the complete order details,
    // sends an order confirmation email to the customer, and reports back the processing status.
    resource function post .(@http:Payload OrderNotificationRequest orderNotification) returns OrderProcessingResponse|http:BadRequest|http:InternalServerError {
        string orderId = orderNotification.orderId.trim();
        if orderId.length() == 0 {
            log:printWarn("Received order notification with an invalid order id");
            return <http:BadRequest>{
                body: {
                    orderId: orderNotification.orderId,
                    status: "FAILED",
                    message: "orderId must not be empty"
                }
            };
        }

        log:printInfo("Received order notification from SAP Commerce", orderId = orderId);

        sapcommerce:Order|error sapOrderResult = fetchOrderDetails(orderId);
        if sapOrderResult is error {
            return <http:InternalServerError>{
                body: {
                    orderId,
                    status: "FAILED",
                    message: "Unable to retrieve order details from SAP Commerce: " + sapOrderResult.message()
                }
            };
        }

        OrderSummary|error orderSummary = toOrderSummary(sapOrderResult);
        if orderSummary is error {
            log:printError("Failed to transform SAP Commerce order response", 'error = orderSummary, orderId = orderId);
            return <http:InternalServerError>{
                body: {
                    orderId,
                    status: "FAILED",
                    message: "Unable to process order details: " + orderSummary.message()
                }
            };
        }

        error? emailResult = sendOrderConfirmationEmail(orderSummary);
        if emailResult is error {
            return <http:InternalServerError>{
                body: {
                    orderId,
                    status: "FAILED",
                    message: "Order retrieved but failed to send confirmation email: " + emailResult.message()
                }
            };
        }

        return {
            orderId,
            status: "SUCCESS",
            message: "Order processed and confirmation email sent successfully"
        };
    }
}
