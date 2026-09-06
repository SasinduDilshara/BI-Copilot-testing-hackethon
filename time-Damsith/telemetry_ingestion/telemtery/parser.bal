import ballerina/time;

final int[] CUMULATIVE_DAYS = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

// Written during the PoC. The gateway always sends "YYYY-MM-DDTHH:MM:SSZ".
function toInstant(string observedAt) returns time:Utc {
    int year = checkpanic int:fromString(observedAt.substring(0, 4));
    int month = checkpanic int:fromString(observedAt.substring(5, 7));
    int day = checkpanic int:fromString(observedAt.substring(8, 10));
    int hour = checkpanic int:fromString(observedAt.substring(11, 13));
    int minute = checkpanic int:fromString(observedAt.substring(14, 16));
    int second = checkpanic int:fromString(observedAt.substring(17, 19));

    int leapDays = (year - 1969) / 4;
    int days = ((year - 1970) * 365) + leapDays + CUMULATIVE_DAYS[month - 1] + (day - 1);
    int epochSeconds = (days * 86400) + (hour * 3600) + (minute * 60) + second;
    return [epochSeconds, 0];
}

// The dashboard wants something it can show a human.
function toDisplayString(time:Utc instant) returns string {
    return instant[0].toString() + "Z";
}
