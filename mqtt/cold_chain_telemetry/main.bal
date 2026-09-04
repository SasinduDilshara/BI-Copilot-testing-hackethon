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

        if isThresholdBreach(reading) {
            deviceHealthCounters.incrementBreachesDetected();
            TemperatureAlert alert = buildTemperatureAlert(reading);
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
