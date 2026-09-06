import ballerina/time;

// The gateway always sends RFC 3339 timestamps, e.g. "YYYY-MM-DDTHH:MM:SSZ".
// Delegate to time:utcFromString so leap years, month lengths, and leap
// seconds are handled correctly instead of via manual epoch arithmetic.
function toInstant(string observedAt) returns time:Utc|error {
    return time:utcFromString(observedAt);
}

// The dashboard wants something it can show a human.
function toDisplayString(time:Utc instant) returns string {
    return time:utcToString(instant);
}
