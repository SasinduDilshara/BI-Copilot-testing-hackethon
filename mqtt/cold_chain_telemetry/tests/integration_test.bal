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
isolated string? receivedHealthPayload = ();
isolated map<mqtt:Message> receivedCommandResponses = {};

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

service class HealthCaptureService {
    *mqtt:Service;

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        string payloadText = check string:fromBytes(message.payload);
        lock {
            receivedHealthPayload = payloadText;
        }
    }

    remote function onError(mqtt:Error err) returns error? {
    }
}

service class CommandResponseCaptureService {
    *mqtt:Service;

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        lock {
            receivedCommandResponses[testDeviceId] = message.clone();
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

@test:Config {dependsOn: [testMalformedPayloadDoesNotProduceAlert]}
function testRetainedDeviceHealthIsPublishedOnBroker() returns error? {
    mqtt:ListenerConfiguration healthListenerConfig = {
        connectionConfig: {
            username: testMqttUsername,
            password: testMqttPassword,
            secureSocket: {
                cert: testMqttTrustedCertPath
            }
        },
        manualAcks: false
    };

    // A fresh subscriber connecting after the fact should immediately receive the retained health snapshot.
    mqtt:Listener healthListener = check new (testMqttBrokerUrl, "test-health-subscriber-1",
            {topic: deviceHealthTopic, qos: 1}, healthListenerConfig);
    check healthListener.attach(new HealthCaptureService());
    check healthListener.'start();

    // Allow time for the retained message to be delivered on subscription.
    runtime:sleep(3);

    string? capturedHealthPayload;
    lock {
        capturedHealthPayload = receivedHealthPayload;
    }
    test:assertTrue(capturedHealthPayload is string, msg = "A retained device health snapshot should be available on subscription");

    if capturedHealthPayload is string {
        json healthJson = check capturedHealthPayload.fromJsonString();
        DeviceHealth health = check healthJson.cloneWithType(DeviceHealth);
        test:assertEquals(health.status, "online", msg = "Retained health snapshot should report the service as online");
        test:assertTrue(health.messagesReceived > 0, msg = "Retained health snapshot should reflect messages already processed");
    }

    check healthListener.gracefulStop();
}

@test:Config {dependsOn: [testRetainedDeviceHealthIsPublishedOnBroker]}
function testUnconfiguredCargoReadingDoesNotProduceAlert() returns error? {
    string unconfiguredCargoDeviceId = "dev-integration-3";
    string unconfiguredCargoId = "cargo-unconfigured-xyz";
    lock {
        string? _ = receivedAlertPayloads.removeIfHasKey(testDeviceId);
    }

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-temperature-publisher-3", testPublisherConfig);
    string temperatureTopic = string `fleet/${unconfiguredCargoDeviceId}/temperature`;
    string payload = string `{"deviceId":"${unconfiguredCargoDeviceId}","cargoId":"${unconfiguredCargoId}","celsius":25.0,"recordedAt":"2026-09-04T03:54:49Z"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(temperatureTopic, {
        payload: payload.toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the reading for an unconfigured cargo should still succeed at the transport level");

    // Allow time to confirm no alert gets produced.
    runtime:sleep(3);

    string? capturedAlertPayload;
    lock {
        capturedAlertPayload = receivedAlertPayloads[testDeviceId];
    }
    test:assertTrue(capturedAlertPayload is (), msg = "Readings for unconfigured cargos must not result in a published alert");
}

@test:Config {dependsOn: [testUnconfiguredCargoReadingDoesNotProduceAlert]}
function testPingCommandRespondsWithCorrelationDataPreserved() returns error? {
    mqtt:ListenerConfiguration responseListenerConfig = {
        connectionConfig: {
            username: testMqttUsername,
            password: testMqttPassword,
            secureSocket: {
                cert: testMqttTrustedCertPath
            }
        },
        manualAcks: false
    };
    string responseTopic = string `fleet/${testDeviceId}/commands/response`;
    mqtt:Listener responseListener = check new (testMqttBrokerUrl, "test-command-response-subscriber-1",
            {topic: responseTopic, qos: 1}, responseListenerConfig);
    check responseListener.attach(new CommandResponseCaptureService());
    check responseListener.'start();

    // Allow the subscription to establish before publishing.
    runtime:sleep(2);

    byte[] correlationData = "correlation-ping-1".toBytes();
    mqtt:Client commandPublisherClient = check new (testMqttBrokerUrl, "test-command-publisher-1", testPublisherConfig);
    string commandTopic = string `fleet/${testDeviceId}/commands`;
    string commandPayload = string `{"commandType":"PING","deviceId":"${testDeviceId}"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = commandPublisherClient->publish(commandTopic, {
        payload: commandPayload.toBytes(),
        qos: 1,
        properties: {
            responseTopic: responseTopic,
            correlationData: correlationData
        }
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the PING command should succeed");

    // Allow time for the service to process and respond.
    runtime:sleep(3);

    mqtt:Message? capturedResponse;
    lock {
        capturedResponse = receivedCommandResponses[testDeviceId].clone();
    }
    test:assertTrue(capturedResponse is mqtt:Message, msg = "A response should have been published for the PING command");

    if capturedResponse is mqtt:Message {
        string responsePayloadText = check string:fromBytes(capturedResponse.payload);
        json responseJson = check responsePayloadText.fromJsonString();
        DeviceCommandResponse response = check responseJson.cloneWithType(DeviceCommandResponse);
        test:assertEquals(response.deviceId, testDeviceId, msg = "Response should reference the originating device");
        test:assertEquals(response.commandType, "PING", msg = "Response should reflect the PING command type");
        test:assertEquals(response.message, "PONG", msg = "PING response should carry a PONG message");

        byte[]? responseCorrelationData = capturedResponse.properties?.correlationData;
        test:assertEquals(responseCorrelationData, correlationData, msg = "Response should preserve the original correlation data");
    }

    check responseListener.gracefulStop();
}

@test:Config {dependsOn: [testPingCommandRespondsWithCorrelationDataPreserved]}
function testReportStatusCommandRespondsWithHealthSnapshot() returns error? {
    lock {
        receivedCommandResponses.removeAll();
    }

    mqtt:ListenerConfiguration responseListenerConfig = {
        connectionConfig: {
            username: testMqttUsername,
            password: testMqttPassword,
            secureSocket: {
                cert: testMqttTrustedCertPath
            }
        },
        manualAcks: false
    };
    string responseTopic = string `fleet/${testDeviceId}/commands/response`;
    mqtt:Listener responseListener = check new (testMqttBrokerUrl, "test-command-response-subscriber-2",
            {topic: responseTopic, qos: 1}, responseListenerConfig);
    check responseListener.attach(new CommandResponseCaptureService());
    check responseListener.'start();

    runtime:sleep(2);

    byte[] correlationData = "correlation-report-status-1".toBytes();
    mqtt:Client commandPublisherClient = check new (testMqttBrokerUrl, "test-command-publisher-2", testPublisherConfig);
    string commandTopic = string `fleet/${testDeviceId}/commands`;
    string commandPayload = string `{"commandType":"REPORT_STATUS","deviceId":"${testDeviceId}"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = commandPublisherClient->publish(commandTopic, {
        payload: commandPayload.toBytes(),
        qos: 1,
        properties: {
            responseTopic: responseTopic,
            correlationData: correlationData
        }
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the REPORT_STATUS command should succeed");

    runtime:sleep(3);

    mqtt:Message? capturedResponse;
    lock {
        capturedResponse = receivedCommandResponses[testDeviceId].clone();
    }
    test:assertTrue(capturedResponse is mqtt:Message, msg = "A response should have been published for the REPORT_STATUS command");

    if capturedResponse is mqtt:Message {
        string responsePayloadText = check string:fromBytes(capturedResponse.payload);
        json responseJson = check responsePayloadText.fromJsonString();
        DeviceCommandResponse response = check responseJson.cloneWithType(DeviceCommandResponse);
        test:assertEquals(response.deviceId, testDeviceId, msg = "Response should reference the originating device");
        test:assertEquals(response.commandType, "REPORT_STATUS", msg = "Response should reflect the REPORT_STATUS command type");
        DeviceHealth? health = response.health;
        test:assertTrue(health is DeviceHealth, msg = "REPORT_STATUS response should carry a device health snapshot");

        byte[]? responseCorrelationData = capturedResponse.properties?.correlationData;
        test:assertEquals(responseCorrelationData, correlationData, msg = "Response should preserve the original correlation data");
    }

    check responseListener.gracefulStop();
}

@test:Config {dependsOn: [testReportStatusCommandRespondsWithHealthSnapshot]}
function testCommandMissingResponseTopicAndCorrelationDataGetsNoResponse() returns error? {
    lock {
        receivedCommandResponses.removeAll();
    }

    mqtt:ListenerConfiguration responseListenerConfig = {
        connectionConfig: {
            username: testMqttUsername,
            password: testMqttPassword,
            secureSocket: {
                cert: testMqttTrustedCertPath
            }
        },
        manualAcks: false
    };
    string responseTopic = string `fleet/${testDeviceId}/commands/response`;
    mqtt:Listener responseListener = check new (testMqttBrokerUrl, "test-command-response-subscriber-3",
            {topic: responseTopic, qos: 1}, responseListenerConfig);
    check responseListener.attach(new CommandResponseCaptureService());
    check responseListener.'start();

    runtime:sleep(2);

    mqtt:Client commandPublisherClient = check new (testMqttBrokerUrl, "test-command-publisher-3", testPublisherConfig);
    string commandTopic = string `fleet/${testDeviceId}/commands`;
    string commandPayload = string `{"commandType":"PING","deviceId":"${testDeviceId}"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = commandPublisherClient->publish(commandTopic, {
        payload: commandPayload.toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the command without responseTopic/correlationData should still succeed at the transport level");

    runtime:sleep(3);

    mqtt:Message? capturedResponse;
    lock {
        capturedResponse = receivedCommandResponses[testDeviceId].clone();
    }
    test:assertTrue(capturedResponse is (), msg = "Commands missing responseTopic or correlationData must not receive a response");

    check responseListener.gracefulStop();
}
