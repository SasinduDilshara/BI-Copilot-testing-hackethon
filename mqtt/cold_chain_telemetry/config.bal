// MQTT broker connection configuration.
configurable string mqttBrokerUrl = ?;
configurable string mqttUsername = ?;
configurable string mqttPassword = ?;
configurable string mqttSubscriberClientId = ?;
configurable string mqttPublisherClientId = ?;

// Path to the PEM certificate (or truststore) trusted for the TLS broker connection.
configurable string mqttTrustedCertPath = ?;

// Subscription configuration.
configurable string temperatureTopicFilter = "fleet/+/temperature";
configurable int temperatureSubscriptionQos = 1;

// Threshold configuration used to detect cold-chain breaches.
configurable decimal maxAllowedCelsius = 8.0;
