import ballerina/time;

// Accumulates readings per device and metric within the currently open
// tumbling window, and produces closed `WindowAggregate` snapshots when
// flushed. All mutable state is guarded by this class's own lock.
public isolated class WindowAggregator {
    private map<WindowAccumulator> accumulatorsByKey = {};
    private string windowStart;

    public isolated function init() {
        self.windowStart = time:utcToString(time:utcNow());
    }

    // Folds a single reading into the accumulator for its device/metric pair,
    // creating a fresh accumulator if this is the first reading seen for that
    // pair in the current window.
    public isolated function addReading(TelemetryReading telemetryReading) {
        lock {
            string accumulatorKey = self.toKey(telemetryReading.deviceId, telemetryReading.metric);
            WindowAccumulator? existingAccumulator = self.accumulatorsByKey[accumulatorKey];
            if existingAccumulator is () {
                self.accumulatorsByKey[accumulatorKey] = {
                    deviceId: telemetryReading.deviceId,
                    siteId: telemetryReading.siteId,
                    metric: telemetryReading.metric,
                    unit: telemetryReading.unit,
                    count: 1,
                    min: telemetryReading.value,
                    max: telemetryReading.value,
                    sum: telemetryReading.value
                };
                return;
            }
            WindowAccumulator updatedAccumulator = {
                deviceId: existingAccumulator.deviceId,
                siteId: existingAccumulator.siteId,
                metric: existingAccumulator.metric,
                unit: existingAccumulator.unit,
                count: existingAccumulator.count + 1,
                min: telemetryReading.value < existingAccumulator.min ? telemetryReading.value : existingAccumulator.min,
                max: telemetryReading.value > existingAccumulator.max ? telemetryReading.value : existingAccumulator.max,
                sum: existingAccumulator.sum + telemetryReading.value
            };
            self.accumulatorsByKey[accumulatorKey] = updatedAccumulator;
        }
    }

    // Closes the current window, returning one `WindowAggregate` per
    // device/metric pair that received at least one reading, and resets the
    // internal state so a new window starts immediately after this call.
    public isolated function 'flush() returns WindowAggregate[] {
        lock {
            string windowEnd = time:utcToString(time:utcNow());
            WindowAggregate[] windowAggregates = [];
            foreach WindowAccumulator accumulator in self.accumulatorsByKey {
                decimal mean = accumulator.sum / <decimal>accumulator.count;
                windowAggregates.push({
                    deviceId: accumulator.deviceId,
                    siteId: accumulator.siteId,
                    metric: accumulator.metric,
                    unit: accumulator.unit,
                    windowStart: self.windowStart,
                    windowEnd: windowEnd,
                    count: accumulator.count,
                    min: accumulator.min,
                    max: accumulator.max,
                    mean: mean
                });
            }
            self.accumulatorsByKey = {};
            self.windowStart = windowEnd;
            return windowAggregates.clone();
        }
    }

    private isolated function toKey(string deviceId, string metric) returns string => deviceId + "|" + metric;
}
