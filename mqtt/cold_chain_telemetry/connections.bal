import ballerina/mqtt;

mqtt:ListenerConfiguration temperatureListenerConfig = {
    connectionConfig: {
        username: mqttUsername,
        password: mqttPassword,
        secureSocket: {
            cert: mqttTrustedCertPath
        }
    },
    manualAcks: true
};

listener mqtt:Listener temperatureListener = new (mqttBrokerUrl, mqttSubscriberClientId,
    {topic: temperatureTopicFilter, qos: temperatureSubscriptionQos}, temperatureListenerConfig);

mqtt:ClientConfiguration alertPublisherConfig = {
    connectionConfig: {
        username: mqttUsername,
        password: mqttPassword,
        secureSocket: {
            cert: mqttTrustedCertPath
        }
    }
};

final mqtt:Client alertPublisherClient = check new (mqttBrokerUrl, mqttPublisherClientId, alertPublisherConfig);

// Offline last-will message delivered by the broker if the health client disconnects unexpectedly.
final DeviceHealth offlineDeviceHealth = {
    status: "offline",
    messagesReceived: 0,
    messagesRejected: 0,
    breachesDetected: 0,
    alertsPublished: 0
};

mqtt:ClientConfiguration deviceHealthClientConfig = {
    connectionConfig: {
        username: mqttUsername,
        password: mqttPassword,
        secureSocket: {
            cert: mqttTrustedCertPath
        }
    },
    willDetails: {
        willMessage: {
            payload: offlineDeviceHealth.toJsonString().toBytes(),
            qos: temperatureSubscriptionQos,
            retained: true
        },
        destinationTopic: deviceHealthTopic
    }
};

final mqtt:Client deviceHealthClient = check new (mqttBrokerUrl, mqttHealthClientId, deviceHealthClientConfig);

final DeviceHealthCounters deviceHealthCounters = new;
