import ballerinax/solace;

// Listener bound to a durable topic endpoint (DTE) subscribed to the store telemetry topic
// hierarchy. Receive timestamps and expiration calculation are enabled so that every consumed
// message carries a populated `receiveTimestamp` and `expiration`, letting the service drop
// readings whose expiration has already passed.
listener solace:Listener telemetryListener = check new (solaceBrokerUrl,
    messageVpn = solaceVpnName,
    auth = {
        username: solaceUsername,
        password: solacePassword
    },
    generateReceiveTimestamps = true,
    calculateMessageExpiration = true
);

// Producer used to publish device telemetry alerts onto `retail/alerts/{region}/{storeId}`.
final solace:MessageProducer alertProducer = check new (solaceBrokerUrl,
    messageVpn = solaceVpnName,
    auth = {
        username: solaceUsername,
        password: solacePassword
    }
);

