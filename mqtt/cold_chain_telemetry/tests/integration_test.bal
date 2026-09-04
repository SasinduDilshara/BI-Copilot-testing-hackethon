import ballerina/lang.runtime;
import ballerina/mqtt;
import ballerina/test;

configurable string testMqttBrokerUrl = ?;
configurable string testMqttUsername = ?;
configurable string testMqttPassword = ?;
configurable string testMqttTrustedCertPath = ?;

final string testDeviceId = "dev-integration-1";
final string testCargoId = "cargo-integration-1";

isolated map<string> receivedAlertPayloads = {};

mqtt:ClientConfiguration testPublisherConfig = {
    connectionConfig: {
        username: testMqttUsername,
        password: testMqttPassword,
        secureSocket: {
            cert: testMqttTrustedCertPath
        }
    }
};

service class AlertCaptureService {
    *mqtt:Service;

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        string payloadText = check string:fromBytes(message.payload);
        lock {
            receivedAlertPayloads[testDeviceId] = payloadText;
        }
    }

    remote function onError(mqtt:Error err) returns error? {
    }
}

@test:Config {}
function testBreachingReadingProducesAlertOnBroker() returns error? {
    mqtt:ListenerConfiguration alertListenerConfig = {
        connectionConfig: {
            username: testMqttUsername,
            password: testMqttPassword,
            secureSocket: {
                cert: testMqttTrustedCertPath
            }
        },
        manualAcks: false
    };
    string alertTopic = buildAlertTopic(testDeviceId);
    mqtt:Listener alertListener = check new (testMqttBrokerUrl, "test-alert-subscriber-1",
            {topic: alertTopic, qos: 1}, alertListenerConfig);
    check alertListener.attach(new AlertCaptureService());
    check alertListener.'start();

    // Allow the subscription to establish before publishing.
    runtime:sleep(2);

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-temperature-publisher-1", testPublisherConfig);
    string temperatureTopic = string `fleet/${testDeviceId}/temperature`;
    string breachingPayload = string `{"deviceId":"${testDeviceId}","cargoId":"${testCargoId}","celsius":15.5,"recordedAt":"2026-09-04T03:54:49Z"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(temperatureTopic, {
        payload: breachingPayload.toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the temperature reading should succeed");

    // Allow time for the service to process and publish the alert.
    runtime:sleep(3);

    string? capturedAlertPayload;
    lock {
        capturedAlertPayload = receivedAlertPayloads[testDeviceId];
    }
    test:assertTrue(capturedAlertPayload is string, msg = "An alert should have been published for the breaching reading");

    if capturedAlertPayload is string {
        json alertJson = check capturedAlertPayload.fromJsonString();
        TemperatureAlert alert = check alertJson.cloneWithType(TemperatureAlert);
        test:assertEquals(alert.deviceId, testDeviceId, msg = "Alert should reference the originating device");
        test:assertEquals(alert.cargoId, testCargoId, msg = "Alert should reference the originating cargo");
        test:assertEquals(alert.celsius, 15.5d, msg = "Alert should carry the breaching celsius value");
    }

    check alertListener.gracefulStop();
}

@test:Config {dependsOn: [testBreachingReadingProducesAlertOnBroker]}
function testMalformedPayloadDoesNotProduceAlert() returns error? {
    string noAlertDeviceId = "dev-integration-2";
    lock {
        string? _ = receivedAlertPayloads.removeIfHasKey(testDeviceId);
    }

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-temperature-publisher-2", testPublisherConfig);
    string temperatureTopic = string `fleet/${noAlertDeviceId}/temperature`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(temperatureTopic, {
        payload: "this-is-not-json".toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the malformed payload should still succeed at the transport level");

    // Allow time to confirm no alert gets produced.
    runtime:sleep(3);

    string? capturedAlertPayload;
    lock {
        capturedAlertPayload = receivedAlertPayloads[testDeviceId];
    }
    test:assertTrue(capturedAlertPayload is (), msg = "Malformed payloads must not result in a published alert");
}
