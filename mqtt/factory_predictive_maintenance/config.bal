// MQTT broker connection configuration.
configurable string mqttBrokerUrl = ?;
configurable string mqttUsername = ?;
configurable string mqttPassword = ?;
configurable string mqttSubscriberClientId = "factory-predictive-maintenance-subscriber-1";
configurable string mqttPublisherClientId = "factory-predictive-maintenance-publisher-1";
configurable string mqttDiagnosticsClientId = "factory-predictive-maintenance-diagnostics-1";

// Path to the PEM certificate (or truststore) trusted for the TLS broker connection.
configurable string mqttTrustedCertPath = ?;

// Subscription configuration.
configurable string vibrationTopicFilter = "plant/+/machines/+/vibration";
configurable int sensorSubscriptionQos = 1;

// Predictive-maintenance threshold applied to all machines.
configurable decimal maxVibrationMm = 10.0;

// Diagnostic request/response correlation configuration. When a maintenance alert fires, a
// diagnostic request is published to the affected machine and a matching response is expected
// on the shared diagnostics response topic filter within the configured timeout.
configurable string diagnosticsResponseTopicFilter = "plant/+/machines/+/diagnostics/response";
configurable int diagnosticsSubscriptionQos = 1;
configurable decimal diagnosticsResponseTimeoutSeconds = 10.0;
