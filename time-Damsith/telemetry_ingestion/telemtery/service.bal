import ballerina/http;
import ballerina/log;
import ballerina/time;

configurable int stalenessThresholdMinutes = 15;
configurable int retentionDays = 30;

service /telemetry on new http:Listener(8080) {

    resource function post readings(GatewayReading[] batch) returns IngestResult {
        int accepted = 0;
        int rejected = 0;
        foreach GatewayReading gr in batch {
            time:Utc|error observedAt = toInstant(gr.observedAt);
            if observedAt is error {
                rejected += 1;
                log:printWarn("unparseable timestamp", deviceId = gr.deviceId, observedAt = gr.observedAt);
                continue;
            }
            Reading reading = {
                deviceId: gr.deviceId,
                observedAt,
                value: gr.value,
                unit: gr.unit
            };
            storeReading(reading);

            DeviceState state = devices[gr.deviceId] ?: {
                deviceId: gr.deviceId,
                lastSeen: observedAt,
                readingCount: 0,
                stale: false
            };
            if time:utcDiffSeconds(observedAt, state.lastSeen) > 0d {
                state.lastSeen = observedAt;
            }
            state.readingCount += 1;
            state.stale = false;
            devices[gr.deviceId] = state;
            accepted += 1;
        }
        return {accepted, rejected};
    }

    resource function get devices/[string deviceId]/latest() returns json|http:NotFound {
        Reading? latest = latestReading(deviceId);
        if latest is () {
            http:NotFound nf = {body: {message: "unknown device"}};
            return nf;
        }
        return {
            deviceId: latest.deviceId,
            observedAt: toDisplayString(latest.observedAt),
            value: latest.value,
            unit: latest.unit
        };
    }

    resource function get stale() returns DeviceState[] {
        time:Utc now = time:utcNow();
        DeviceState[] result = [];
        foreach string deviceId in devices.keys() {
            DeviceState state = devices.get(deviceId);
            time:Seconds age = time:utcDiffSeconds(now, state.lastSeen);
            state.stale = age > <decimal>(stalenessThresholdMinutes * 60);
            devices[deviceId] = state;
            if state.stale {
                result.push(state);
            }
        }
        return result;
    }

    resource function post maintenance/prune() returns json {
        int removed = prune(retentionDays);
        return {removed};
    }
}
