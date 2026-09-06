import ballerina/time;

// Outcome of a single usage-aggregation run: the real start/end timestamps finance relies on, plus the
// run duration in seconds. durationSeconds is measured independently of the wall clock (see
// startAggregationRun/endAggregationRun below), so a mid-run NTP clock correction cannot make it negative
// or otherwise wrong, even though startedAt/endedAt remain genuine wall-clock dates.
public type AggregationRunMetrics record {|
    time:Utc startedAt;
    time:Utc endedAt;
    decimal durationSeconds;
|};

// Handle returned by startAggregationRun and passed to endAggregationRun. startedAt is the real wall-clock
// timestamp recorded on the aggregation record; monotonicStart is purely an internal reference point used
// to compute elapsed run time and is never stored or exposed alongside finance-facing data.
type AggregationRunHandle record {|
    time:Utc startedAt;
    decimal monotonicStart;
|};

// Marks the start of a usage-aggregation run. Captures both the real UTC timestamp (for the aggregation
// record) and a monotonic reference point (for duration measurement only).
function startAggregationRun() returns AggregationRunHandle {
    return {
        startedAt: time:utcNow(),
        monotonicStart: time:monotonicNow()
    };
}

// Marks the end of a usage-aggregation run and returns its metrics. The duration is computed entirely from
// time:monotonicNow(), which is guaranteed to keep increasing from call to call and is unaffected by the
// system clock being adjusted (e.g. an NTP correction mid-run) - so it can never come out negative. The
// endedAt timestamp is still taken from the wall clock, since it is a real date finance needs, not a
// duration measurement.
function endAggregationRun(AggregationRunHandle runHandle) returns AggregationRunMetrics {
    decimal monotonicEnd = time:monotonicNow();
    decimal durationSeconds = monotonicEnd - runHandle.monotonicStart;

    return {
        startedAt: runHandle.startedAt,
        endedAt: time:utcNow(),
        durationSeconds: durationSeconds
    };
}
