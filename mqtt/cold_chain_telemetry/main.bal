import ballerina/log;
import ballerina/mqtt;

service mqtt:Service on temperatureListener {

    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        TemperatureReading|error reading = parseTemperatureReading(message.payload);

        if reading is error {
            log:printError("Rejected malformed temperature payload", 'error = reading, topic = message.topic);
            return;
        }

        log:printInfo("Processed temperature reading", deviceId = reading.deviceId,
                cargoId = reading.cargoId, celsius = reading.celsius);

        if isThresholdBreach(reading) {
            TemperatureAlert alert = buildTemperatureAlert(reading);
            string alertTopic = buildAlertTopic(reading.deviceId);
            mqtt:DeliveryToken|mqtt:Error deliveryResult = alertPublisherClient->publish(alertTopic, {
                payload: alert.toJsonString().toBytes(),
                qos: temperatureSubscriptionQos
            });

            if deliveryResult is mqtt:Error {
                log:printError("Failed to publish threshold breach alert", 'error = deliveryResult, topic = alertTopic);
            } else {
                log:printWarn("Published threshold breach alert", topic = alertTopic, deviceId = reading.deviceId);
            }
        }
    }

    remote function onError(mqtt:Error err) returns error? {
        log:printError("MQTT listener error", 'error = err);
    }
}
