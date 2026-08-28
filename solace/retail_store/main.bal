import ballerina/http;
import ballerina/log;
import ballerinax/solace;

# Consumes store device telemetry readings via a durable topic endpoint (DTE) subscribed to
# `retail/telemetry/{region}/{storeId}/{deviceType}`. The `*` single-level wildcard is used for
# each of the region, storeId and deviceType segments so that telemetry from every store and
# device type is matched - see `telemetryTopicName` in config.bal for what each wildcard matches.
#
# The listener has `generateReceiveTimestamps` and `calculateMessageExpiration` enabled, so every
# delivered message carries a populated `receiveTimestamp` and `expiration`. Readings whose
# expiration has already passed are dropped instead of being processed.
@solace:ServiceConfig {
    topicName: telemetryTopicName,
    durability: solace:DURABLE,
    endpointName: telemetryEndpointName,
    ackMode: solace:CLIENT_ACK
}
service on telemetryListener {

    # Invoked for every device telemetry reading delivered from the durable topic endpoint.
    #
    # + message - The device telemetry message, with the payload data-bound into `DeviceTelemetry`
    # + caller - Handle used to acknowledge the message
    # + return - A `solace:Error` if acknowledgement fails
    remote function onMessage(DeviceTelemetryMessage message, solace:Caller caller) returns solace:Error? {
        DeviceTelemetry deviceTelemetry = message.payload;

        if !isRegionAllowed(deviceTelemetry) {
            incrementBlockedRegionCount();
            log:printWarn("Dropping device telemetry reading from a region not on the allow list",
                    storeId = deviceTelemetry.storeId, region = deviceTelemetry.region,
                    deviceId = deviceTelemetry.deviceId, metric = deviceTelemetry.metric);
            check caller->ack(message);
            return;
        }

        if isExpired(message?.expiration) {
            incrementSkippedExpiredCount();
            log:printWarn("Dropping expired device telemetry reading",
                    storeId = deviceTelemetry.storeId, deviceId = deviceTelemetry.deviceId,
                    metric = deviceTelemetry.metric, expiration = message?.expiration);
            check caller->ack(message);
            return;
        }

        // Buffered in a bounded, shed-oldest buffer awaiting downstream processing (e.g.
        // persistence, aggregation) instead of being processed synchronously here.
        bufferTelemetryReading(deviceTelemetry);
        incrementProcessedCount();

        log:printInfo("Device telemetry reading processed",
                storeId = deviceTelemetry.storeId, region = deviceTelemetry.region,
                deviceType = deviceTelemetry.deviceType, deviceId = deviceTelemetry.deviceId,
                metric = deviceTelemetry.metric, value = deviceTelemetry.value, unit = deviceTelemetry.unit,
                readingAt = deviceTelemetry.readingAt);

        decimal? crossedThreshold = checkThresholdCrossed(deviceTelemetry);
        if crossedThreshold is decimal {
            solace:Error? alertResult = publishDeviceTelemetryAlert(deviceTelemetry, crossedThreshold);
            if alertResult is solace:Error {
                log:printError("Failed to publish device telemetry alert",
                        storeId = deviceTelemetry.storeId, deviceId = deviceTelemetry.deviceId,
                        metric = deviceTelemetry.metric, 'error = alertResult);
            } else {
                log:printInfo("Device telemetry alert published",
                        storeId = deviceTelemetry.storeId, region = deviceTelemetry.region,
                        deviceType = deviceTelemetry.deviceType, metric = deviceTelemetry.metric,
                        value = deviceTelemetry.value, threshold = crossedThreshold);
            }
        }

        check caller->ack(message);
    }

    # Invoked when a delivered message cannot be dispatched to `onMessage`, most commonly because
    # the underlying guaranteed consumer flow is disrupted.
    #
    # + err - The failure that prevented dispatch
    remote function onError(solace:Error err) returns solace:Error? {
        if err is solace:FlowDownError {
            log:printError("Telemetry consumer flow is down; the underlying connection was lost " +
                    "and the flow will be re-established once connectivity is restored", 'error = err);
            return;
        }

        if err is solace:InactiveFlowError {
            log:printWarn("Telemetry consumer flow is inactive; another instance in the client " +
                    "cluster is likely active and this instance will remain on standby", 'error = err);
            return;
        }

        log:printError("Unexpected error while consuming device telemetry", 'error = err);
    }
}

service /telemetry on new http:Listener(servicePort) {

    # Returns the current state of the bounded telemetry buffer and processing counters.
    #
    # + return - The current telemetry health snapshot
    resource function get health() returns TelemetryHealthOk {
        return <TelemetryHealthOk>{
            body: buildTelemetryHealth()
        };
    }
}

