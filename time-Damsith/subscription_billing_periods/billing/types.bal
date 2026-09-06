import ballerina/time;

// Calendar date (year/month/day) without time-of-day. All billing computations are done at day granularity
// in the subscription's billing calendar, avoiding any time-zone/duration drift over long spans.
public type CalendarDate record {|
    int year;
    int month;
    int day;
|};

// A subscription being billed monthly on its signup anniversary.
public type Subscription record {|
    string subscriptionId;
    CalendarDate startDate;
    decimal monthlyAmount;
    // IANA time zone ID (e.g. "America/Sao_Paulo", "Europe/Berlin") for the customer's own country.
    // Cycle boundaries are local midnight in this zone, not UTC midnight.
    string timeZoneId;
|};

// The inclusive start and exclusive end of a single billing cycle, plus the date the next cycle is billed on.
// periodStart/periodEnd are the calendar-day boundaries (used for calendar-day proration), while
// periodStartInstant/periodEndInstant are the exact UTC instants of local midnight for those boundaries
// in the subscription's own time zone - this is what genuinely marks the start/end of the cycle.
public type BillingPeriod record {|
    int cycleNumber;
    CalendarDate periodStart;
    // Exclusive end - the period covers [periodStart, periodEnd).
    CalendarDate periodEnd;
    CalendarDate nextBillingDate;
    // The exact UTC instant of local midnight at the start of the cycle.
    time:Utc periodStartInstant;
    // The exact UTC instant of local midnight at the end of the cycle (exclusive).
    time:Utc periodEndInstant;
    time:Utc nextBillingInstant;
    // Total number of calendar days in this cycle (periodEnd - periodStart), used as the denominator
    // for calendar-day proration. This stays a whole number of days even when the cycle contains a
    // daylight-saving clock change.
    int cycleLengthDays;
    // Actual elapsed duration of the cycle in seconds (periodEndInstant - periodStartInstant). This will
    // differ from cycleLengthDays * 86400 exactly when the cycle contains a DST transition, e.g. a
    // 25-hour "fall back" day - the cycle is still exactly one calendar cycle, just not exactly 24h/day.
    decimal cycleLengthSeconds;
|};

// Represents a plan a customer can be subscribed to.
public type Plan record {|
    string planId;
    decimal monthlyAmount;
|};

public enum LineItemKind {
    PRIOR_PLAN_CREDIT,
    NEW_PLAN_CHARGE,
    RECURRING_CHARGE
}

// A single billed line item, ready to be rendered on an invoice.
public type LineItem record {|
    LineItemKind kind;
    string description;
    CalendarDate periodStart;
    CalendarDate periodEnd;
    int days;
    // Negative for credits, positive for charges.
    decimal amount;
|};

// Result of prorating a mid-cycle plan change within a single billing cycle.
public type ProrationResult record {|
    // Credit for the unused remainder of the old plan (negative amount).
    LineItem priorPlanCredit;
    // Charge for the new plan for the remaining days of the cycle (positive amount).
    LineItem newPlanCharge;
    // Net amount to bill immediately (creditAmount + chargeAmount).
    decimal netAmount;
|};
