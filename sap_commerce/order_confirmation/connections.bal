import ballerina/email;
import ballerinax/sap.commerce.webservices as sapcommerce;

// Client used to retrieve complete order details from SAP Commerce.
final sapcommerce:Client sapCommerceClient = check new ({
    auth: {
        token: sapCommerceAccessToken
    }
}, sapCommerceServiceUrl);

// Client used to send order confirmation emails via SMTP.
final email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword, {
    port: smtpPort,
    security: email:START_TLS_NEVER
});
