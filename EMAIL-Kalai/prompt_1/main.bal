import ballerina/email;
import ballerina/http;
import ballerina/mime;
import ballerina/time;

service /orders on new http:Listener(8080) {

    resource function post confirm(@http:Payload OrderConfirmationRequest orderRequest) returns OrderConfirmationResponse {
        OrderConfirmationResponse sendResponse = sendOrderConfirmationEmail(orderRequest);
        if sendResponse.status == "sent" {
            lock {
                sentOrders[orderRequest.orderId] = orderRequest.clone();
            }
        }
        return sendResponse;
    }

    resource function get [string orderId]/resend() returns OrderConfirmationResponse|http:NotFound {
        OrderConfirmationRequest? storedOrder;
        lock {
            storedOrder = sentOrders[orderId].clone();
        }
        if storedOrder is () {
            return {
                body: string `No order found for orderId: ${orderId}`
            };
        }
        return sendOrderConfirmationEmail(storedOrder);
    }
}

// Constructs and sends the order confirmation email, including a plain text invoice attachment.
function sendOrderConfirmationEmail(OrderConfirmationRequest orderRequest) returns OrderConfirmationResponse {
    string plainTextBody = buildPlainTextBody(orderRequest);
    string htmlBody = buildHtmlBody(orderRequest);

    string invoiceDate = time:utcToString(time:utcNow());
    string invoiceText = buildInvoiceText(orderRequest, invoiceDate);

    mime:Entity invoiceAttachment = new;
    mime:ContentDisposition invoiceDisposition = new;
    invoiceDisposition.fileName = string `invoice-${orderRequest.orderId}.txt`;
    invoiceDisposition.disposition = "attachment";
    invoiceAttachment.setContentDisposition(invoiceDisposition);
    invoiceAttachment.setText(invoiceText, contentType = mime:TEXT_PLAIN);

    email:Message confirmationEmail = {
        to: [orderRequest.customerEmail],
        cc: ["orders@company.com"],
        subject: string `Order Confirmation - ${orderRequest.orderId}`,
        body: plainTextBody,
        htmlBody: htmlBody,
        replyTo: ["support@company.com"],
        attachments: invoiceAttachment
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
