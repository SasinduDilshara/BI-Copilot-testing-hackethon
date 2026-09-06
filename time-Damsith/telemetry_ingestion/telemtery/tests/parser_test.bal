import ballerina/test;
import ballerina/time;

// Regression test: the Kuala Lumpur gateway sends local time with a numeric
// UTC offset (e.g. "+08:00") instead of "Z". toInstant must resolve any valid
// RFC 3339 offset to the same absolute instant as its UTC equivalent.
@test:Config {}
function testOffsetTimestampMatchesEquivalentUtc() returns error? {
    time:Utc utcInstant = check toInstant("2024-01-01T12:00:00Z");
    time:Utc offsetInstant = check toInstant("2024-01-01T20:00:00+08:00");

    test:assertEquals(time:utcDiffSeconds(offsetInstant, utcInstant), 0d,
            msg = "timestamp with +08:00 offset should resolve to the same instant as its UTC equivalent");
}

// Negative offsets must also be normalized correctly.
@test:Config {}
function testNegativeOffsetTimestampMatchesEquivalentUtc() returns error? {
    time:Utc utcInstant = check toInstant("2024-01-01T12:00:00Z");
    time:Utc offsetInstant = check toInstant("2024-01-01T07:00:00-05:00");

    test:assertEquals(time:utcDiffSeconds(offsetInstant, utcInstant), 0d,
            msg = "timestamp with -05:00 offset should resolve to the same instant as its UTC equivalent");
}

// Sub-second precision must survive alongside a non-Z offset.
@test:Config {}
function testOffsetTimestampPreservesSubSecondPrecision() returns error? {
    time:Utc utcInstant = check toInstant("2024-01-01T12:00:00.250Z");
    time:Utc offsetInstant = check toInstant("2024-01-01T20:00:00.250+08:00");

    test:assertEquals(time:utcDiffSeconds(offsetInstant, utcInstant), 0d,
            msg = "sub-second precision should be preserved when a non-Z offset is present");
}

// A device reporting via an offset gateway just now must not be treated as
// having reported hours ago (the actual production symptom).
@test:Config {}
function testOffsetTimestampIsNotTreatedAsStale() returns error? {
    time:Utc now = time:utcNow();
    // +08:00 is 8 hours ahead of UTC, so the KL-local clock reading "now"
    // shows 8 hours later than the UTC instant.
    time:Utc shifted = time:utcAddSeconds(now, 8 * 3600);
    string localWithOffset = check toOffsetTimestamp(shifted, "+08:00");

    time:Utc reportedInstant = check toInstant(localWithOffset);
    time:Seconds age = time:utcDiffSeconds(now, reportedInstant);

    // Allow a small tolerance for whole-second truncation when rendering the
    // test's timestamp string and the real time elapsed during the test run.
    // Before the fix this would be off by exactly the 8-hour offset (28800s).
    boolean withinTolerance = age >= -2d && age <= 2d;
    test:assertEquals(withinTolerance, true,
            msg = "a reading reported 'now' via an offset gateway should not appear hours stale, age was " + age.toString());
}

// Helper: renders a UTC instant as an RFC 3339 string expressed with the
// given numeric offset, mirroring how an offset-based gateway would report
// its local time.
function toOffsetTimestamp(time:Utc localInstant, string offsetSign) returns string|error {
    time:Civil civil = time:utcToCivil(localInstant);
    string year = civil.year.toString();
    string month = civil.month < 10 ? "0" + civil.month.toString() : civil.month.toString();
    string day = civil.day < 10 ? "0" + civil.day.toString() : civil.day.toString();
    string hour = civil.hour < 10 ? "0" + civil.hour.toString() : civil.hour.toString();
    string minute = civil.minute < 10 ? "0" + civil.minute.toString() : civil.minute.toString();
    decimal? secondField = civil.second;
    decimal seconds = secondField is decimal ? secondField : 0d;
    int wholeSeconds = <int>seconds;
    string second = wholeSeconds < 10 ? "0" + wholeSeconds.toString() : wholeSeconds.toString();
    return string `${year}-${month}-${day}T${hour}:${minute}:${second}${offsetSign}`;
}
