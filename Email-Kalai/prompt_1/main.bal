import ballerina/email;
import ballerina/http;

service /orders on new http:Listener(8080) {

    resource function post confirm(@http:Payload OrderConfirmationRequest orderRequest) returns OrderConfirmationResponse {
        string plainTextBody = buildPlainTextBody(orderRequest);
        string htmlBody = buildHtmlBody(orderRequest);

        email:Message confirmationEmail = {
            to: [orderRequest.customerEmail],
            cc: ["orders@company.com"],
            subject: string `Order Confirmation - ${orderRequest.orderId}`,
            body: plainTextBody,
            htmlBody: htmlBody,
            replyTo: ["support@company.com"]
        };

        email:Error? sendResult = smtpClient->sendMessage(confirmationEmail);
        if sendResult is email:Error {
            return {
                orderId: orderRequest.orderId,
                status: "failed",
                errorMessage: sendResult.message()
            };
        }

        return {
            orderId: orderRequest.orderId,
            status: "sent"
        };
    }
}
