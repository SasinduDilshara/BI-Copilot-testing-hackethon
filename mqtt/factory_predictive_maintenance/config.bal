// MQTT broker connection configuration.
configurable string mqttBrokerUrl = ?;
configurable string mqttUsername = ?;
configurable string mqttPassword = ?;
configurable string mqttSubscriberClientId = "factory-predictive-maintenance-subscriber-1";
configurable string mqttPublisherClientId = "factory-predictive-maintenance-publisher-1";
configurable string mqttDiagnosticsClientId = "factory-predictive-maintenance-diagnostics-1";

// Path to the PEM certificate (or truststore) trusted for the TLS broker connection.
configurable string mqttTrustedCertPath = ?;

// Subscription configuration. A single listener subscribes to both topics; QoS 1 is used for
// the shared subscription since it satisfies the at-least-once delivery needs of both readings.
configurable string vibrationTopicFilter = "plant/+/machines/+/vibration";
configurable string runtimeTopicFilter = "plant/+/machines/+/runtime";
configurable int sensorSubscriptionQos = 1;

// Predictive-maintenance thresholds applied to all machines.
configurable decimal maxVibrationMm = 10.0;
configurable decimal maxRuntimeHours = 500.0;

// Diagnostic request/response correlation configuration. When a maintenance alert fires, a
// diagnostic request is published to the affected machine and a matching response is expected
// on the shared diagnostics response topic filter within the configured timeout.
configurable string diagnosticsResponseTopicFilter = "plant/+/machines/+/diagnostics/response";
configurable int diagnosticsSubscriptionQos = 1;
configurable decimal diagnosticsResponseTimeoutSeconds = 10.0;
