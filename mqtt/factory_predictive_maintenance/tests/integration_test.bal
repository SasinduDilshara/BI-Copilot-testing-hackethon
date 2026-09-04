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

isolated map<mqtt:Message> receivedDiagnosticRequests = {};

service class DiagnosticRequestCaptureService {
    *mqtt:Service;

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        lock {
            receivedDiagnosticRequests[testMachineId] = message.clone();
        }
    }

    remote function onError(mqtt:Error err) returns error? {
    }
}

@test:Config {dependsOn: [testMalformedPayloadDoesNotProduceAlert]}
function testAlertTriggersDiagnosticRequestWithResponseTopicAndCorrelationData() returns error? {
    lock {
        mqtt:Message? _ = receivedDiagnosticRequests.removeIfHasKey(testMachineId);
    }

    mqtt:ListenerConfiguration diagnosticRequestListenerConfig = {
        connectionConfig: {
            username: testMqttUsername,
            password: testMqttPassword,
            secureSocket: {
                cert: testMqttTrustedCertPath
            }
        },
        manualAcks: false
    };
    string diagnosticRequestTopic = buildDiagnosticRequestTopic(testPlantId, testMachineId);
    mqtt:Listener diagnosticRequestListener = check new (testMqttBrokerUrl, "test-diagnostic-request-subscriber-1",
            {topic: diagnosticRequestTopic, qos: 1}, diagnosticRequestListenerConfig);
    check diagnosticRequestListener.attach(new DiagnosticRequestCaptureService());
    check diagnosticRequestListener.'start();

    // Allow the subscription to establish before publishing.
    runtime:sleep(2);

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-vibration-publisher-3", testPublisherConfig);
    string vibrationTopic = string `plant/${testPlantId}/machines/${testMachineId}/vibration`;
    string breachingPayload = string `{"vibrationMm":22.0,"recordedAt":"2026-09-04T03:54:49Z"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(vibrationTopic, {
        payload: breachingPayload.toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the vibration reading should succeed");

    // Allow time for the service to process the breach and publish the diagnostic request.
    runtime:sleep(3);

    mqtt:Message? capturedRequest;
    lock {
        capturedRequest = receivedDiagnosticRequests[testMachineId].clone();
    }
    test:assertTrue(capturedRequest is mqtt:Message, msg = "A diagnostic request should have been published for the breaching reading");

    if capturedRequest is mqtt:Message {
        string requestPayloadText = check string:fromBytes(capturedRequest.payload);
        json requestJson = check requestPayloadText.fromJsonString();
        DiagnosticRequest request = check requestJson.cloneWithType(DiagnosticRequest);
        test:assertEquals(request.plantId, testPlantId, msg = "Diagnostic request should reference the originating plant");
        test:assertEquals(request.machineId, testMachineId, msg = "Diagnostic request should reference the originating machine");
        test:assertEquals(request.sensorType, "vibration", msg = "Diagnostic request should reflect the sensor type that triggered it");
        test:assertTrue(request.correlationId.trim().length() > 0, msg = "Diagnostic request should carry a non-empty correlation id");

        mqtt:MessageProperties? properties = capturedRequest.properties;
        string? responseTopic = properties?.responseTopic;
        byte[]? correlationData = properties?.correlationData;
        test:assertTrue(responseTopic is string, msg = "Diagnostic request should carry a responseTopic property");
        test:assertTrue(correlationData is byte[], msg = "Diagnostic request should carry correlationData property");

        if responseTopic is string && correlationData is byte[] {
            test:assertEquals(responseTopic, buildDiagnosticResponseTopic(testPlantId, testMachineId),
                    msg = "responseTopic should match the expected diagnostic response topic");
            string correlationIdFromProperties = check string:fromBytes(correlationData);
            test:assertEquals(correlationIdFromProperties, request.correlationId,
                    msg = "correlationData should match the correlationId carried in the request payload");

            // Respond with matching correlationData so the service can correlate the response.
            DiagnosticCounters countersBeforeResponse = diagnosticTracker.snapshot();
            mqtt:Client responsePublisherClient = check new (testMqttBrokerUrl, "test-diagnostic-response-publisher-1", testPublisherConfig);
            string responsePayload = string `{"plantId":"${testPlantId}","machineId":"${testMachineId}","correlationId":"${request.correlationId}","status":"OK","details":"diagnostics nominal"}`;
            mqtt:DeliveryToken|mqtt:Error responsePublishResult = responsePublisherClient->publish(responseTopic, {
                payload: responsePayload.toBytes(),
                qos: 1
            });
            test:assertTrue(responsePublishResult is mqtt:DeliveryToken, msg = "Publishing the diagnostic response should succeed");

            // Allow time for the service to consume and correlate the response.
            runtime:sleep(3);

            DiagnosticCounters countersAfterResponse = diagnosticTracker.snapshot();
            test:assertTrue(countersAfterResponse.diagnosticsAnswered > countersBeforeResponse.diagnosticsAnswered,
                    msg = "diagnosticsAnswered should increase once the correlated response is consumed");
        }
    }

    check diagnosticRequestListener.gracefulStop();
}

@test:Config {dependsOn: [testAlertTriggersDiagnosticRequestWithResponseTopicAndCorrelationData]}
function testUnansweredDiagnosticRequestTimesOutAndIsCounted() returns error? {
    DiagnosticCounters countersBeforeTimeout = diagnosticTracker.snapshot();

    mqtt:Client publisherClient = check new (testMqttBrokerUrl, "test-runtime-publisher-3", testPublisherConfig);
    string timeoutMachineId = "machine-integration-timeout-1";
    string runtimeTopic = string `plant/${testPlantId}/machines/${timeoutMachineId}/runtime`;
    string breachingPayload = string `{"runtimeHours":700.0,"recordedAt":"2026-09-04T03:54:49Z"}`;
    mqtt:DeliveryToken|mqtt:Error publishResult = publisherClient->publish(runtimeTopic, {
        payload: breachingPayload.toBytes(),
        qos: 1
    });
    test:assertTrue(publishResult is mqtt:DeliveryToken, msg = "Publishing the runtime reading should succeed");

    // Allow the diagnostic request to be dispatched, then wait past the configured response
    // timeout without ever sending a response, so the request should expire as unanswered.
    runtime:sleep(diagnosticsResponseTimeoutSeconds + 5.0);

    DiagnosticCounters countersAfterTimeout = diagnosticTracker.snapshot();
    test:assertTrue(countersAfterTimeout.diagnosticsSent > countersBeforeTimeout.diagnosticsSent,
            msg = "diagnosticsSent should increase once the diagnostic request for the breach is dispatched");
    test:assertTrue(countersAfterTimeout.diagnosticsUnanswered > countersBeforeTimeout.diagnosticsUnanswered,
            msg = "diagnosticsUnanswered should increase once the unanswered diagnostic request times out");
}
