import ballerina/lang.runtime;
import ballerina/mqtt;
import ballerina/test;

configurable string testMqttBrokerUrl = ?;
configurable string testMqttUsername = ?;
configurable string testMqttPassword = ?;
configurable string testMqttTrustedCertPath = ?;

final string testPlantId = "plant-integration-1";
final string testMachineId = "machine-integration-1";

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
            receivedAlertPayloads[testPlantId] = payloadText;
        }
    }

    remote function onError(mqtt:Error err) returns error? {
    }
}

isolated map<string> receivedDebugPayloads = {};

service class DebugCaptureService {
    *mqtt:Service;

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        string payloadText = check string:fromBytes(message.payload);
        string topic = message.topic ?: "unknown";
        lock {
            receivedDebugPayloads[topic] = payloadText;
        }
    }

    remote function onError(mqtt:Error err) returns error? {
    }
}

@test:Config {}
function testDebugWildcardArraySubscriptionReceivesMessage() returns error? {
    mqtt:ListenerConfiguration debugListenerConfig = {
        connectionConfig: {
            username: testMqttUsername,
            password: testMqttPassword,
            secureSocket: {
                cert: testMqttTrustedCertPath
            }
        },
        manualAcks: false
    };
    mqtt:Listener debugListener = check new (testMqttBrokerUrl, "test-debug-wildcard-subscriber-1",
            {topic: "fleet/+/debugvibration", qos: 1}, debugListenerConfig);
    check debugListener.attach(new DebugCaptureService());
    check debugListener.'start();

    runtime:sleep(2);

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-debug-publisher-1", testPublisherConfig);
    string debugTopic = string `fleet/plant-debug-1/debugvibration`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(debugTopic, {
        payload: "{\"vibrationMm\":5.0,\"recordedAt\":\"2026-09-04T03:54:49Z\"}".toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the debug message should succeed");

    runtime:sleep(3);

    string? capturedDebugPayload;
    lock {
        capturedDebugPayload = receivedDebugPayloads[debugTopic];
    }
    test:assertTrue(capturedDebugPayload is string, msg = "The wildcard array subscription should have received the message");

    check debugListener.gracefulStop();
}

@test:Config {}
function testBreachingVibrationReadingProducesAlertOnBroker() returns error? {
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
    string alertTopic = buildMaintenanceAlertTopic(testPlantId);
    mqtt:Listener alertListener = check new (testMqttBrokerUrl, "test-alert-subscriber-1",
            {topic: alertTopic, qos: 1}, alertListenerConfig);
    check alertListener.attach(new AlertCaptureService());
    check alertListener.'start();

    // Allow the subscription to establish before publishing.
    runtime:sleep(2);

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-vibration-publisher-1", testPublisherConfig);
    string vibrationTopic = string `plant/${testPlantId}/machines/${testMachineId}/vibration`;
    string breachingPayload = string `{"vibrationMm":18.5,"recordedAt":"2026-09-04T03:54:49Z"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(vibrationTopic, {
        payload: breachingPayload.toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the vibration reading should succeed");

    // Allow time for the service to process and publish the alert.
    runtime:sleep(3);

    string? capturedAlertPayload;
    lock {
        capturedAlertPayload = receivedAlertPayloads[testPlantId];
    }
    test:assertTrue(capturedAlertPayload is string, msg = "An alert should have been published for the breaching vibration reading");

    if capturedAlertPayload is string {
        json alertJson = check capturedAlertPayload.fromJsonString();
        MaintenanceAlert alert = check alertJson.cloneWithType(MaintenanceAlert);
        test:assertEquals(alert.plantId, testPlantId, msg = "Alert should reference the originating plant");
        test:assertEquals(alert.machineId, testMachineId, msg = "Alert should reference the originating machine");
        test:assertEquals(alert.sensorType, "vibration", msg = "Alert should be typed as a vibration alert");
        test:assertEquals(alert.value, 18.5d, msg = "Alert should carry the breaching vibration value");
    }

    check alertListener.gracefulStop();
}

@test:Config {dependsOn: [testBreachingVibrationReadingProducesAlertOnBroker]}
function testBreachingRuntimeReadingProducesAlertOnBroker() returns error? {
    lock {
        string? _ = receivedAlertPayloads.removeIfHasKey(testPlantId);
    }

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
    string alertTopic = buildMaintenanceAlertTopic(testPlantId);
    mqtt:Listener alertListener = check new (testMqttBrokerUrl, "test-alert-subscriber-2",
            {topic: alertTopic, qos: 1}, alertListenerConfig);
    check alertListener.attach(new AlertCaptureService());
    check alertListener.'start();

    runtime:sleep(2);

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-runtime-publisher-1", testPublisherConfig);
    string runtimeTopic = string `plant/${testPlantId}/machines/${testMachineId}/runtime`;
    string breachingPayload = string `{"runtimeHours":650.0,"recordedAt":"2026-09-04T03:54:49Z"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(runtimeTopic, {
        payload: breachingPayload.toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the runtime reading should succeed");

    runtime:sleep(3);

    string? capturedAlertPayload;
    lock {
        capturedAlertPayload = receivedAlertPayloads[testPlantId];
    }
    test:assertTrue(capturedAlertPayload is string, msg = "An alert should have been published for the breaching runtime reading");

    if capturedAlertPayload is string {
        json alertJson = check capturedAlertPayload.fromJsonString();
        MaintenanceAlert alert = check alertJson.cloneWithType(MaintenanceAlert);
        test:assertEquals(alert.plantId, testPlantId, msg = "Alert should reference the originating plant");
        test:assertEquals(alert.machineId, testMachineId, msg = "Alert should reference the originating machine");
        test:assertEquals(alert.sensorType, "runtime", msg = "Alert should be typed as a runtime alert");
        test:assertEquals(alert.value, 650.0d, msg = "Alert should carry the breaching runtime value");
    }

    check alertListener.gracefulStop();
}

@test:Config {dependsOn: [testBreachingRuntimeReadingProducesAlertOnBroker]}
function testNonBreachingReadingDoesNotProduceAlert() returns error? {
    string noAlertMachineId = "machine-integration-2";
    lock {
        string? _ = receivedAlertPayloads.removeIfHasKey(testPlantId);
    }

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-vibration-publisher-2", testPublisherConfig);
    string vibrationTopic = string `plant/${testPlantId}/machines/${noAlertMachineId}/vibration`;
    string withinLimitPayload = string `{"vibrationMm":2.0,"recordedAt":"2026-09-04T03:54:49Z"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(vibrationTopic, {
        payload: withinLimitPayload.toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the within-limit vibration reading should succeed");

    // Allow time to confirm no alert gets produced.
    runtime:sleep(3);

    string? capturedAlertPayload;
    lock {
        capturedAlertPayload = receivedAlertPayloads[testPlantId];
    }
    test:assertTrue(capturedAlertPayload is (), msg = "Readings within configured limits must not result in a published alert");
}

@test:Config {dependsOn: [testNonBreachingReadingDoesNotProduceAlert]}
function testMalformedPayloadDoesNotProduceAlert() returns error? {
    string malformedMachineId = "machine-integration-3";
    lock {
        string? _ = receivedAlertPayloads.removeIfHasKey(testPlantId);
    }

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-runtime-publisher-2", testPublisherConfig);
    string runtimeTopic = string `plant/${testPlantId}/machines/${malformedMachineId}/runtime`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(runtimeTopic, {
        payload: "this-is-not-json".toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the malformed payload should still succeed at the transport level");

    // Allow time to confirm no alert gets produced.
    runtime:sleep(3);

    string? capturedAlertPayload;
    lock {
        capturedAlertPayload = receivedAlertPayloads[testPlantId];
    }
    test:assertTrue(capturedAlertPayload is (), msg = "Malformed payloads must not result in a published alert");
}
