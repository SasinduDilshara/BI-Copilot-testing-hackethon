import ballerina/email;
import ballerina/oauth2;

final oauth2:ClientCredentialsGrantConfig smtpOAuth2Config = {
    tokenUrl: tokenUrl,
    clientId: clientId,
    clientSecret: clientSecret,
    scopes: scopes
};

final email:SmtpConfiguration smtpConfig = {
    port: smtpPort,
    security: email:START_TLS_ALWAYS,
    auth: smtpOAuth2Config
};

final email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, clientConfig = smtpConfig);
