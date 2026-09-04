import ballerina/log;
import ballerina/mqtt;

service mqtt:Service on temperatureListener {

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        deviceHealthCounters.incrementMessagesReceived();

        TemperatureReading|error reading = parseTemperatureReading(message.payload);

        if reading is error {
            deviceHealthCounters.incrementMessagesRejected();
            log:printError("Rejected malformed temperature payload", 'error = reading, topic = message.topic);
            publishDeviceHealthSnapshot();
            return;
        }

        log:printInfo("Processed temperature reading", deviceId = reading.deviceId,
                cargoId = reading.cargoId, celsius = reading.celsius);

        decimal|error thresholdCelsius = resolveCargoThreshold(reading.cargoId);
        if thresholdCelsius is error {
            deviceHealthCounters.incrementMessagesRejected();
            log:printError("Rejected temperature reading for unconfigured cargo", 'error = thresholdCelsius,
                    topic = message.topic, cargoId = reading.cargoId);
            publishDeviceHealthSnapshot();
            return;
        }

        if isThresholdBreach(reading, thresholdCelsius) {
            deviceHealthCounters.incrementBreachesDetected();
            TemperatureAlert alert = buildTemperatureAlert(reading, thresholdCelsius);
            string alertTopic = buildAlertTopic(reading.deviceId);
            mqtt:DeliveryToken|mqtt:Error deliveryResult = alertPublisherClient->publish(alertTopic, {
                payload: alert.toJsonString().toBytes(),
                qos: temperatureSubscriptionQos
            });

            if deliveryResult is mqtt:Error {
                log:printError("Failed to publish threshold breach alert", 'error = deliveryResult, topic = alertTopic);
                publishDeviceHealthSnapshot();
                return;
            }

            deviceHealthCounters.incrementAlertsPublished();
            log:printWarn("Published threshold breach alert", topic = alertTopic, deviceId = reading.deviceId);
        }

        publishDeviceHealthSnapshot();

        mqtt:Error? completeResult = caller->complete();
        if completeResult is mqtt:Error {
            log:printError("Failed to acknowledge processed message", 'error = completeResult, topic = message.topic);
        }
    }

    remote function onError(mqtt:Error err) returns error? {
        log:printError("MQTT listener error", 'error = err);
    }
}

service mqtt:Service on deviceCommandListener {

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        mqtt:MessageProperties? properties = message.properties;
        string? responseTopic = properties?.responseTopic;
        byte[]? correlationData = properties?.correlationData;

        if responseTopic is () || correlationData is () {
            log:printError("Rejected device command missing responseTopic or correlationData", topic = message.topic);
            return;
        }

        DeviceCommand|error command = parseDeviceCommand(message.payload);
        if command is error {
            log:printError("Rejected malformed device command", 'error = command, topic = message.topic);
            return;
        }

        DeviceCommandResponse response;
        if command.commandType == "PING" {
            response = buildPingResponse(command);
        } else {
            DeviceHealth health = deviceHealthCounters.snapshot();
            response = buildReportStatusResponse(command, health);
        }

        mqtt:Error? respondResult = caller->respond({
            payload: response.toJsonString().toBytes(),
            topic: responseTopic,
            properties: {
                correlationData: correlationData
            }
        });

        if respondResult is mqtt:Error {
            log:printError("Failed to respond to device command", 'error = respondResult, topic = responseTopic,
                    deviceId = command.deviceId);
            return;
        }

        log:printInfo("Responded to device command", commandType = command.commandType, deviceId = command.deviceId,
                responseTopic = responseTopic);

        mqtt:Error? completeResult = caller->complete();
        if completeResult is mqtt:Error {
            log:printError("Failed to acknowledge processed device command", 'error = completeResult, topic = message.topic);
        }
    }

    remote function onError(mqtt:Error err) returns error? {
        log:printError("MQTT listener error", 'error = err);
    }
}

# Publishes the current device health snapshot as a retained message to the device health topic.
function publishDeviceHealthSnapshot() {
    DeviceHealth health = deviceHealthCounters.snapshot();
    mqtt:DeliveryToken|mqtt:Error deliveryResult = deviceHealthClient->publish(deviceHealthTopic, {
        payload: health.toJsonString().toBytes(),
        qos: temperatureSubscriptionQos,
        retained: true
    });

    if deliveryResult is mqtt:Error {
        log:printError("Failed to publish retained device health snapshot", 'error = deliveryResult, topic = deviceHealthTopic);
    }
}
