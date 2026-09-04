import ballerina/lang.runtime;
import ballerina/log;
import ballerina/mqtt;
import ballerina/uuid;

service mqtt:Service on sensorListener {

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        string topic = message.topic ?: "";

        [string, string]|error plantAndMachineIds = extractPlantAndMachineIds(topic);
        if plantAndMachineIds is error {
            log:printError("Rejected message on unrecognized topic", 'error = plantAndMachineIds, topic = topic);
            return;
        }

        [string, string] [plantId, machineId] = plantAndMachineIds;

        if topic.endsWith("/vibration") {
            check self.handleVibrationMessage(message.payload, plantId, machineId, topic);
        } else {
            log:printError("Rejected message on unsupported sensor topic", topic = topic);
        }

        mqtt:Error? completeResult = caller->complete();
        if completeResult is mqtt:Error {
            log:printError("Failed to acknowledge processed message", 'error = completeResult, topic = topic);
        }
    }

    remote function onError(mqtt:Error err) returns error? {
        log:printError("MQTT listener error", 'error = err);
    }

    function handleVibrationMessage(byte[] payload, string plantId, string machineId, string topic) returns error? {
        VibrationReading|error reading = parseVibrationReading(payload, plantId, machineId);
        if reading is error {
            log:printError("Rejected malformed vibration payload", 'error = reading, topic = topic);
            return;
        }

        log:printInfo("Processed vibration reading", plantId = reading.plantId, machineId = reading.machineId,
                vibrationMm = reading.vibrationMm);
        machineStateStore.recordVibrationReading(reading);

        if isVibrationBreach(reading, maxVibrationMm) {
            MaintenanceAlert alert = buildVibrationAlert(reading, maxVibrationMm);
            check publishMaintenanceAlert(alert);
            dispatchDiagnosticRequest(alert);
        }
    }
}

service mqtt:Service on diagnosticsResponseListener {

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        DiagnosticResponse|error response = parseDiagnosticResponse(message.payload);
        if response is error {
            log:printError("Rejected malformed diagnostic response", 'error = response, topic = message.topic);
        } else {
            PendingDiagnostic? resolved = diagnosticTracker.resolveResponse(response.correlationId);
            if resolved is PendingDiagnostic {
                log:printInfo("Correlated diagnostic response", plantId = resolved.plantId,
                        machineId = resolved.machineId, correlationId = response.correlationId, status = response.status);
            } else {
                log:printWarn("Received diagnostic response for an unknown or already-timed-out correlationId",
                        correlationId = response.correlationId);
            }
        }

        mqtt:Error? completeResult = caller->complete();
        if completeResult is mqtt:Error {
            log:printError("Failed to acknowledge processed diagnostic response", 'error = completeResult, topic = message.topic);
        }
    }

    remote function onError(mqtt:Error err) returns error? {
        log:printError("MQTT listener error", 'error = err);
    }
}

# Publishes a diagnostic request for the machine referenced by a maintenance alert, registers it
# as pending a correlated response, and schedules a timeout to mark it unanswered if no response
# arrives in time. Failures to dispatch the diagnostic request are logged but do not fail the
# caller, since a failed diagnostic dispatch must not block acknowledgement of the triggering reading.
#
# + alert - The maintenance alert that triggered this diagnostic request
function dispatchDiagnosticRequest(MaintenanceAlert alert) {
    string correlationId = uuid:createRandomUuid();
    DiagnosticRequest request = buildDiagnosticRequest(alert, correlationId);
    string requestTopic = buildDiagnosticRequestTopic(alert.plantId, alert.machineId);
    string responseTopic = buildDiagnosticResponseTopic(alert.plantId, alert.machineId);

    mqtt:DeliveryToken|mqtt:Error deliveryResult = alertPublisherClient->publish(requestTopic, {
        payload: request.toJsonString().toBytes(),
        qos: sensorSubscriptionQos,
        properties: {
            responseTopic: responseTopic,
            correlationData: correlationId.toBytes()
        }
    });

    if deliveryResult is mqtt:Error {
        log:printError("Failed to publish diagnostic request", 'error = deliveryResult, topic = requestTopic);
        return;
    }

    diagnosticTracker.registerPending(correlationId, {
        plantId: alert.plantId,
        machineId: alert.machineId,
        sensorType: alert.sensorType
    });
    log:printInfo("Published diagnostic request", topic = requestTopic, responseTopic = responseTopic,
            correlationId = correlationId, plantId = alert.plantId, machineId = alert.machineId);

    _ = start expireDiagnosticAfterTimeout(correlationId);
}

# Waits for the configured diagnostics response timeout and then expires the diagnostic request
# if no correlated response has arrived by then, marking it as unanswered.
#
# + correlationId - The correlation identifier of the diagnostic request to expire
function expireDiagnosticAfterTimeout(string correlationId) {
    runtime:sleep(diagnosticsResponseTimeoutSeconds);
    boolean expired = diagnosticTracker.expireIfPending(correlationId);
    if expired {
        log:printWarn("Diagnostic request timed out without a correlated response", correlationId = correlationId);
    }
}

# Publishes a maintenance alert to the plant-specific maintenance topic.
#
# + alert - The maintenance alert to publish
# + return - An error if publishing fails
function publishMaintenanceAlert(MaintenanceAlert alert) returns error? {
    string alertTopic = buildMaintenanceAlertTopic(alert.plantId);
    mqtt:DeliveryToken|mqtt:Error deliveryResult = alertPublisherClient->publish(alertTopic, {
        payload: alert.toJsonString().toBytes(),
        qos: sensorSubscriptionQos
    });

    if deliveryResult is mqtt:Error {
        log:printError("Failed to publish maintenance alert", 'error = deliveryResult, topic = alertTopic);
        return deliveryResult;
    }

    log:printWarn("Published maintenance alert", topic = alertTopic, plantId = alert.plantId,
            machineId = alert.machineId, sensorType = alert.sensorType);
}
