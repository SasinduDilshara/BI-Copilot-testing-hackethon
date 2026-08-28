import ballerina/time;
import ballerinax/solace;

# Mutable telemetry processing state (the bounded, shed-oldest buffer plus the processing
# counters surfaced on `GET /telemetry/health`), grouped into a single record so it can be
# accessed atomically within one `lock` statement. Written to from the topic endpoint
# subscription (main.bal), and read from the health check resource (main.bal).
isolated TelemetryState telemetryState = {
    telemetryBuffer: [],
    shedCount: 0,
    processedCount: 0,
    skippedExpiredCount: 0,
    blockedRegionCount: 0
};

isolated function incrementProcessedCount() {
    lock {
        telemetryState.processedCount += 1;
    }
}

isolated function incrementSkippedExpiredCount() {
    lock {
        telemetryState.skippedExpiredCount += 1;
    }
}

isolated function incrementBlockedRegionCount() {
    lock {
        telemetryState.blockedRegionCount += 1;
    }
}

# Appends a device telemetry reading onto the bounded buffer. When the buffer is already at
# `telemetryBufferCapacity`, the oldest buffered reading is shed (discarded) to make room for the
# newest one instead of blocking or rejecting the newest reading.
#
# + deviceTelemetry - The device telemetry reading to buffer
isolated function bufferTelemetryReading(DeviceTelemetry deviceTelemetry) {
    lock {
        if telemetryState.telemetryBuffer.length() >= telemetryBufferCapacity {
            _ = telemetryState.telemetryBuffer.shift();
            telemetryState.shedCount += 1;
        }
        telemetryState.telemetryBuffer.push(deviceTelemetry.clone());
    }
}

# Builds the current telemetry health snapshot.
#
# + return - The current buffer state and processing counters
isolated function buildTelemetryHealth() returns TelemetryHealth {
    lock {
        return {
            bufferedCount: telemetryState.telemetryBuffer.length(),
            bufferCapacity: telemetryBufferCapacity,
            shedCount: telemetryState.shedCount,
            processedCount: telemetryState.processedCount,
            skippedExpiredCount: telemetryState.skippedExpiredCount,
            blockedRegionCount: telemetryState.blockedRegionCount
        };
    }
}

# Checks whether a device telemetry message has already expired, based on the broker-calculated
# `expiration` timestamp (populated because the listener has `calculateMessageExpiration`
# enabled). An `expiration` of zero means the message never expires.
#
# + expiration - The broker-calculated expiration timestamp of the message, if present
# + return - `true` if a non-zero expiration timestamp has already passed relative to the
# current time
function isExpired(int? expiration) returns boolean {
    if expiration is () || expiration == 0 {
        return false;
    }

    time:Utc currentTime = time:utcNow();
    int currentTimeMillis = currentTime[0] * 1000;
    return expiration < currentTimeMillis;
}

# Determines whether a device telemetry reading originates from a region on the configured
# allow list.
#
# + deviceTelemetry - The device telemetry reading to check
# + return - `true` if the reading's region is on the `allowedRegions` allow list
function isRegionAllowed(DeviceTelemetry deviceTelemetry) returns boolean {
    return allowedRegions.indexOf(deviceTelemetry.region) is int;
}

# Determines whether a device telemetry reading's metric value has crossed the threshold
# configured for its device type.
#
# + deviceTelemetry - The device telemetry reading to check
# + return - The configured threshold if the reading's value has crossed it, or `()` if the
# device type has no configured threshold or the value has not crossed it
function checkThresholdCrossed(DeviceTelemetry deviceTelemetry) returns decimal? {
    decimal? threshold = deviceTypeThresholds[deviceTelemetry.deviceType];
    if threshold is () {
        return ();
    }
    if deviceTelemetry.value > threshold {
        return threshold;
    }
    return ();
}

# Builds the hierarchical Solace topic name for a device telemetry alert of the form
# `retail/alerts/{region}/{storeId}`.
#
# + deviceTelemetry - The device telemetry reading the alert is raised for
# + return - The hierarchical topic name
function buildAlertTopic(DeviceTelemetry deviceTelemetry) returns string {
    return string `retail/alerts/${deviceTelemetry.region}/${deviceTelemetry.storeId}`;
}

# Builds the correlation properties for a device telemetry alert, carried in the alert message's
# `properties` map (the `userData` field was previously used for this but was too small to be
# useful).
#
# + deviceTelemetry - The device telemetry reading the alert is raised for
# + return - The correlation properties to attach to the alert message
function buildAlertCorrelationProperties(DeviceTelemetry deviceTelemetry) returns map<solace:Property> {
    time:Utc currentTime = time:utcNow();
    return {
        storeId: deviceTelemetry.storeId,
        triggeredAt: currentTime[0],
        severity: 1
    };
}

# Publishes a device telemetry alert onto `retail/alerts/{region}/{storeId}` with direct
# (at-most-once) delivery, a short time-to-live and top priority so the alert is not queued
# behind routine telemetry traffic, carrying the correlation data in the message's `properties`.
#
# + deviceTelemetry - The device telemetry reading that crossed its threshold
# + threshold - The configured threshold that was crossed
# + return - A `solace:Error` if publishing fails
function publishDeviceTelemetryAlert(DeviceTelemetry deviceTelemetry, decimal threshold) returns solace:Error? {
    DeviceTelemetryAlert deviceTelemetryAlert = {
        storeId: deviceTelemetry.storeId,
        region: deviceTelemetry.region,
        deviceType: deviceTelemetry.deviceType,
        deviceId: deviceTelemetry.deviceId,
        metric: deviceTelemetry.metric,
        value: deviceTelemetry.value,
        threshold,
        unit: deviceTelemetry.unit
    };

    map<solace:Property> properties = buildAlertCorrelationProperties(deviceTelemetry);
    string topicName = buildAlertTopic(deviceTelemetry);

    solace:Message alertMessage = {
        payload: deviceTelemetryAlert,
        deliveryMode: solace:DIRECT,
        priority: alertPriority,
        timeToLive: alertTimeToLive,
        properties
    };

    check alertProducer->send(alertMessage, {topicName});
}

