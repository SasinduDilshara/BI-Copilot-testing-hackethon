import ballerina/mqtt;

mqtt:ListenerConfiguration sensorListenerConfig = {
    connectionConfig: {
        username: mqttUsername,
        password: mqttPassword,
        secureSocket: {
            cert: mqttTrustedCertPath
        }
    },
    manualAcks: true
};

listener mqtt:Listener sensorListener = new (mqttBrokerUrl, mqttSubscriberClientId, [
    {topic: vibrationTopicFilter, qos: sensorSubscriptionQos},
    {topic: runtimeTopicFilter, qos: sensorSubscriptionQos}
], sensorListenerConfig);

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

final MachineStateStore machineStateStore = new;

mqtt:ListenerConfiguration diagnosticsResponseListenerConfig = {
    connectionConfig: {
        username: mqttUsername,
        password: mqttPassword,
        secureSocket: {
            cert: mqttTrustedCertPath
        }
    },
    manualAcks: true
};

listener mqtt:Listener diagnosticsResponseListener = new (mqttBrokerUrl, mqttDiagnosticsClientId,
    {topic: diagnosticsResponseTopicFilter, qos: diagnosticsSubscriptionQos}, diagnosticsResponseListenerConfig);

final DiagnosticTracker diagnosticTracker = new;
