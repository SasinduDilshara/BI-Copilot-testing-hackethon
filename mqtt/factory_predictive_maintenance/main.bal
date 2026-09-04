import ballerina/log;
import ballerina/mqtt;

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
        } else if topic.endsWith("/runtime") {
            check self.handleRuntimeMessage(message.payload, plantId, machineId, topic);
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
        }
    }

    function handleRuntimeMessage(byte[] payload, string plantId, string machineId, string topic) returns error? {
        RuntimeReading|error reading = parseRuntimeReading(payload, plantId, machineId);
        if reading is error {
            log:printError("Rejected malformed runtime payload", 'error = reading, topic = topic);
            return;
        }

        log:printInfo("Processed runtime reading", plantId = reading.plantId, machineId = reading.machineId,
                runtimeHours = reading.runtimeHours);
        machineStateStore.recordRuntimeReading(reading);

        if isRuntimeBreach(reading, maxRuntimeHours) {
            MaintenanceAlert alert = buildRuntimeAlert(reading, maxRuntimeHours);
            check publishMaintenanceAlert(alert);
        }
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
