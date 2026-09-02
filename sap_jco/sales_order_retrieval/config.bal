import ballerinax/sap.jco;

// ============================================================================
// Configuration for the SAP ECC (SAP JCo) destination and the SMTP notification
// mailbox. All values are externalized as configurables — no credentials are
// hardcoded. Populate these in Config.toml at deployment time.
// ============================================================================

# SAP ECC application server host (jco.client.ashost), e.g. "sap-ecc.example.com".
configurable string sapAppServerHost = ?;

# SAP ECC system number (jco.client.sysnr), e.g. "00".
configurable string sapSystemNumber = ?;

# SAP ECC client / mandant (jco.client.client), e.g. "100".
configurable string sapClient = ?;

# SAP ECC integration user (jco.client.user). This is a dedicated technical user
# with least-privilege authorization limited to BAPI_SALESORDER_GETDETAIL.
configurable string sapUser = ?;

# SAP ECC password (jco.client.passwd) for the integration user. Never logged
# or exposed in any API response.
configurable string sapPassword = ?;

# SAP ECC logon language (jco.client.lang), e.g. "EN".
configurable string sapLanguage = "EN";

# SMTP server host used to send the sales order notification email.
configurable string smtpHost = ?;

# SMTP account user name (sender mailbox).
configurable string smtpUsername = ?;

# SMTP account password / app password.
configurable string smtpPassword = ?;

# SMTP server port.
configurable int smtpPort = 587;

# Mailbox that receives the sales order notification email.
configurable string notificationRecipient = "orders@example.com";

# Number of retry attempts for transient SAP connection failures.
configurable int sapRetryCount = 2;

# Delay, in seconds, between SAP connection retry attempts.
configurable decimal sapRetryDelaySeconds = 2;

# SAP JCo destination configuration assembled from the configurable values above.
# This is the representative equivalent of the jco.client.* properties file:
# jco.client.ashost, jco.client.sysnr, jco.client.client,
# jco.client.user, jco.client.passwd, jco.client.lang
jco:DestinationConfig sapDestinationConfig = {
    ashost: sapAppServerHost,
    sysnr: sapSystemNumber,
    jcoClient: sapClient,
    user: sapUser,
    passwd: sapPassword,
    lang: sapLanguage
};
