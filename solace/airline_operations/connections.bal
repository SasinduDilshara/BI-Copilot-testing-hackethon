import ballerinax/solace;

# Resolves the Solace authentication configuration based on the configured `authMode`.
#
# + return - The basic-auth or OAuth2 access-token auth configuration
function resolveSolaceAuthConfig() returns solace:AuthConfiguration {
    if authMode == "OAUTH2" {
        return {
            issuer: solaceOAuth2Issuer,
            accessToken: solaceOAuth2AccessToken
        };
    }

    return {
        username: solaceUsername,
        password: solacePassword
    };
}

final solace:AuthConfiguration solaceAuthConfig = resolveSolaceAuthConfig();

final solace:SecureSocket solaceSecureSocket = {
    trustStore: {
        location: solaceTrustStoreLocation,
        password: solaceTrustStorePassword
    },
    keyStore: {
        location: solaceKeyStoreLocation,
        password: solaceKeyStorePassword,
        keyPassword: solaceKeyPassword
    },
    trustedCommonNames: solaceTrustedCommonNames,
    excludedProtocols: [solace:TLSV1_1]
};

final solace:RetryConfiguration solaceRetryConfig = {
    connectRetries: solaceConnectRetries,
    reconnectRetries: solaceReconnectRetries,
    reconnectRetryWait: solaceReconnectRetryWait
};

final solace:MessageProducer solaceProducer = check new (solaceBrokerUrl,
    messageVpn = solaceVpnName,
    auth = solaceAuthConfig,
    secureSocket = solaceSecureSocket,
    retryConfig = solaceRetryConfig
);

listener solace:Listener disruptionsListener = check new (solaceBrokerUrl,
    messageVpn = solaceVpnName,
    auth = solaceAuthConfig,
    secureSocket = solaceSecureSocket,
    retryConfig = solaceRetryConfig
);

listener solace:Listener rebookingListener = check new (solaceBrokerUrl,
    messageVpn = solaceVpnName,
    auth = solaceAuthConfig,
    secureSocket = solaceSecureSocket,
    retryConfig = solaceRetryConfig
);
