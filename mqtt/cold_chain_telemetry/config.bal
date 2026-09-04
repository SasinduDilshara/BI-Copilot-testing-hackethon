// MQTT broker connection configuration.
configurable string mqttBrokerUrl = ?;
configurable string mqttUsername = ?;
configurable string mqttPassword = ?;
configurable string mqttSubscriberClientId = ?;
configurable string mqttPublisherClientId = ?;
configurable string mqttHealthClientId = ?;
configurable string mqttCommandsClientId = ?;

// Path to the PEM certificate (or truststore) trusted for the TLS broker connection.
configurable string mqttTrustedCertPath = ?;

// Subscription configuration.
configurable string temperatureTopicFilter = "fleet/+/temperature";
configurable int temperatureSubscriptionQos = 1;

// Per-cargo cold-chain temperature thresholds in Celsius, keyed by cargoId. Readings for
// cargos that are not present in this map are rejected as unconfigured.
configurable map<decimal> cargoThresholds = {
    "cargo-1": 8.0,
    "cargo-integration-1": 8.0
};

// Topic on which the retained device health snapshot and last-will offline message are published.
configurable string deviceHealthTopic = "fleet/service/health";

// Device command subscription configuration.
configurable string deviceCommandsTopicFilter = "fleet/+/commands";
configurable int deviceCommandsSubscriptionQos = 1;
