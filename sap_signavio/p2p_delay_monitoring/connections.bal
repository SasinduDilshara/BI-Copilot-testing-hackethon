// Client initializations for the external systems used by this integration:
// 1. SAP Signavio - source of Purchase-to-Pay process monitoring information.
// 2. SMTP server  - channel used to notify the responsible procurement manager.
//
// Both clients are created lazily (on first actual use) rather than eagerly at
// module-load time. This keeps the module loadable - and therefore testable
// with injected mock clients - even when the real Signavio/SMTP configurables
// have not been supplied, since tests never fall through to these getters.

import ballerina/email;
import ballerinax/sap.signavio;

signavio:Client? signavioClientInstance = ();
email:SmtpClient? smtpClientInstance = ();

# Returns the shared SAP Signavio client, creating it on first use.
#
# + return - The Signavio client, or an error if it could not be created
function getSignavioClient() returns signavio:Client|error {
    signavio:Client? existingClient = signavioClientInstance;
    if existingClient is signavio:Client {
        return existingClient;
    }
    signavio:Client newClient = check new ({
        auth: {
            username: signavioUsername,
            password: signavioPassword
        },
        region: signavioRegion
    });
    signavioClientInstance = newClient;
    return newClient;
}

# Returns the shared SMTP client, creating it on first use.
#
# + return - The SMTP client, or an error if it could not be created
function getSmtpClient() returns email:SmtpClient|error {
    email:SmtpClient? existingClient = smtpClientInstance;
    if existingClient is email:SmtpClient {
        return existingClient;
    }
    email:SmtpClient newClient = check new (smtpHost, smtpUsername, smtpPassword, {
        port: smtpPort,
        security: email:START_TLS_AUTO
    });
    smtpClientInstance = newClient;
    return newClient;
}
