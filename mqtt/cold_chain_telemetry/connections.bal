import ballerina/mqtt;

mqtt:ListenerConfiguration temperatureListenerConfig = {
    connectionConfig: {
        username: mqttUsername,
        password: mqttPassword,
        secureSocket: {
            cert: mqttTrustedCertPath
        }
    },
    manualAcks: false
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
