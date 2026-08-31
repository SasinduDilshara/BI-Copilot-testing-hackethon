import ballerina/log;
import ballerina/time;
import ballerinax/nats;

// Running count of readings dropped for being older than stalenessWindowSeconds.
int staleReadingCount = 0;

// Returns the configured alert threshold for the reading's device type, or () if no
// threshold has been configured for that device type.
function getAlertThreshold(DeviceReading deviceReading) returns decimal? {
    return deviceTypeAlertThresholds[deviceReading.deviceType];
}

// Publishes an alert to telemetry.alerts when the reading's metric value crosses
// (exceeds) the configured threshold for its device type.
function publishAlertIfThresholdCrossed(DeviceReading deviceReading) returns nats:Error? {
    decimal? threshold = getAlertThreshold(deviceReading);
    if threshold is () {
        return;
    }
    if deviceReading.value <= threshold {
        return;
    }
    TelemetryAlert telemetryAlert = {
        region: deviceReading.region,
        siteId: deviceReading.siteId,
        deviceType: deviceReading.deviceType,
        metric: deviceReading.metric,
        value: deviceReading.value,
        threshold,
        readingAt: deviceReading.readingAt
    };
    nats:AnydataMessage message = {
        content: telemetryAlert,
        subject: "telemetry.alerts"
    };
    check natsClient->publishMessage(message);
    log:printWarn(string `Alert: ${telemetryAlert.metric}=${telemetryAlert.value} for `
            + string `${telemetryAlert.region}/${telemetryAlert.siteId}/${telemetryAlert.deviceType} `
            + string `crossed threshold ${telemetryAlert.threshold}`);
}

// Returns true if the reading's readingAt timestamp is older than stalenessWindowSeconds
// relative to now. A readingAt value that cannot be parsed is treated as stale so it does
// not get processed as if it were fresh.
function isStaleReading(DeviceReading deviceReading) returns boolean {
    time:Utc|time:Error readingTime = time:utcFromString(deviceReading.readingAt);
    if readingTime is time:Error {
        log:printWarn(string `Unable to parse readingAt '${deviceReading.readingAt}', treating as stale`,
                'error = readingTime);
        return true;
    }
    time:Utc now = time:utcNow();
    decimal ageSeconds = time:utcDiffSeconds(now, readingTime);
    return ageSeconds > stalenessWindowSeconds;
}

// Drops a stale reading: counts it and logs the drop for observability.
function dropStaleReading(DeviceReading deviceReading) {
    lock {
        staleReadingCount += 1;
    }
    log:printWarn(string `Dropping stale reading for ${deviceReading.region}.${deviceReading.siteId}.${deviceReading.deviceType} `
            + string `metric=${deviceReading.metric} readingAt=${deviceReading.readingAt} (staleCount=${staleReadingCount})`);
}

// Processes a fresh (non-stale) reading: raises an alert if its metric value crosses
// the configured threshold for its device type.
function processReading(DeviceReading deviceReading) {
    log:printInfo(string `Reading ${deviceReading.metric}=${deviceReading.value} from `
            + string `${deviceReading.region}/${deviceReading.siteId}/${deviceReading.deviceType} at ${deviceReading.readingAt}`);

    nats:Error? alertResult = publishAlertIfThresholdCrossed(deviceReading);
    if alertResult is nats:Error {
        log:printError(string `Failed to publish alert for ${deviceReading.region}/${deviceReading.siteId}/`
                + string `${deviceReading.deviceType}`, 'error = alertResult);
    }
}

