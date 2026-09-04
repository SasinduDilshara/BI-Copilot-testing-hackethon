// SAP Commerce Web Services connection configuration.
configurable string sapCommerceServiceUrl = ?;
configurable string sapCommerceBaseSiteId = ?;
configurable string sapCommerceAccessToken = ?;

// SMTP connection configuration used to send order confirmation emails.
configurable string smtpHost = ?;
configurable int smtpPort = 465;
configurable string smtpUsername = ?;
configurable string smtpPassword = ?;
configurable string smtpSenderEmail = ?;

// HTTP listener configuration.
configurable int listenerPort = 8090;

// Mock SAP Commerce service listener configuration (used for local testing only).
configurable int mockSapCommercePort = 9091;
