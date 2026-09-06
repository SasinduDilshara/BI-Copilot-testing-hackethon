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
|};

// The inclusive start and exclusive end of a single billing cycle, plus the date the next cycle is billed on.
public type BillingPeriod record {|
    int cycleNumber;
    CalendarDate periodStart;
    // Exclusive end - the period covers [periodStart, periodEnd).
    CalendarDate periodEnd;
    CalendarDate nextBillingDate;
    // Total number of days in this cycle (periodEnd - periodStart), used as the denominator for proration.
    int cycleLengthDays;
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
