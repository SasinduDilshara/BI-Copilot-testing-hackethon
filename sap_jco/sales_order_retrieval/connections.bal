import ballerina/email;
import ballerinax/sap.jco;

// ============================================================================
// Client initialization.
//
// SAP JCo destination and connection lifecycle:
//   1. `sapDestinationConfig` (see config.bal) is the equivalent of a JCo
//      destination properties file (jco.client.ashost, sysnr, client, user,
//      passwd, lang).
//   2. `new jco:Client(sapDestinationConfig)` registers this configuration as a
//      named JCo destination with the underlying JCo runtime
//      (`JCoDestinationManager`). JCo pools and reuses the physical TCP/RFC
//      connection to the SAP application server transparently behind this
//      destination.
//   3. The first RFC call made through the client triggers JCo to open the
//      connection and perform the SAP logon (authentication) using the
//      supplied user/password/client/language against the given application
//      server host and system number.
//   4. The same client instance is reused for every BAPI invocation, so the
//      connection/session is established once and kept alive (and pooled) by
//      JCo rather than re-connecting per-request.
// ============================================================================

jco:Client sapEccClient = check new (sapDestinationConfig);

# SMTP client used to notify the customer service team once a sales order has
# been retrieved from SAP ECC.
email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword, {
    port: smtpPort,
    security: email:START_TLS_AUTO
});
