import ballerina/time;

map<Reading[]> readings = {};
map<DeviceState> devices = {};

function storeReading(Reading reading) {
    Reading[] existing = readings[reading.deviceId] ?: [];
    existing.push(reading);
    readings[reading.deviceId] = existing;
}

function latestReading(string deviceId) returns Reading? {
    Reading[]? all = readings[deviceId];
    if all is () || all.length() == 0 {
        return ();
    }
    Reading latest = all[0];
    foreach Reading r in all {
        if time:utcDiffSeconds(r.observedAt, latest.observedAt) > 0d {
            latest = r;
        }
    }
    return latest;
}

function prune(int retentionDays) returns int {
    time:Utc now = time:utcNow();
    time:Utc cutoff = time:utcAddSeconds(now, <time:Seconds> - (retentionDays * 86400));
    int removed = 0;
    foreach string deviceId in readings.keys() {
        Reading[] kept = [];
        foreach Reading r in readings.get(deviceId) {
            if time:utcDiffSeconds(r.observedAt, cutoff) >= 0d {
                kept.push(r);
            } else {
                removed += 1;
            }
        }
        readings[deviceId] = kept;
    }
    return removed;
}
