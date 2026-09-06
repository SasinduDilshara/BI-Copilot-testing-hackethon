// Returns true if the given year is a Gregorian leap year.
function isLeapYear(int year) returns boolean {
    boolean divisibleBy4 = year % 4 == 0;
    boolean divisibleBy100 = year % 100 == 0;
    boolean divisibleBy400 = year % 400 == 0;
    return divisibleBy4 && (!divisibleBy100 || divisibleBy400);
}

// Returns the number of days in the given month of the given year.
function daysInMonth(int year, int month) returns int {
    int[] daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if month == 2 && isLeapYear(year) {
        return 29;
    }
    return daysPerMonth[month - 1];
}

// Converts a calendar date to a proleptic Gregorian epoch day number (days since 0000-03-01),
// used for exact, drift-free day-count arithmetic between two dates.
function toEpochDay(CalendarDate calendarDate) returns int {
    int year = calendarDate.year;
    int month = calendarDate.month;
    int day = calendarDate.day;

    // Shift so that March is the first month of the year - this makes leap day (Feb 29) the last
    // day of the internal year, which simplifies leap-year arithmetic.
    int shiftedYear = month <= 2 ? year - 1 : year;
    int shiftedMonth = month <= 2 ? month + 10 : month - 2;

    int era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400;
    int yearOfEra = shiftedYear - era * 400;
    int dayOfYear = (153 * shiftedMonth - 1) / 5 + day - 1;
    int dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear;
    return era * 146097 + dayOfEra;
}

// Returns the exact number of days between two calendar dates (toDate - fromDate).
function daysBetween(CalendarDate fromDate, CalendarDate toDate) returns int {
    return toEpochDay(toDate) - toEpochDay(fromDate);
}

// Adds a whole number of calendar months to the subscription's original signup date, clamping the day
// of month to the last valid day when the target month is shorter. Because this always anchors on the
// original signup day (not on a previously clamped date), a signup on the 31st correctly rolls back to
// the 31st in every long month, and a Feb 29 signup correctly rolls to Feb 29 on every future leap year -
// preventing the anniversary date from permanently drifting after landing in a short month once.
function addMonthsClamped(CalendarDate signupDate, int monthsToAdd) returns CalendarDate {
    int totalMonths = (signupDate.year * 12 + (signupDate.month - 1)) + monthsToAdd;
    int targetYear = totalMonths / 12;
    int targetMonth = totalMonths % 12 + 1;

    int lastDayOfTargetMonth = daysInMonth(targetYear, targetMonth);
    int targetDay = signupDate.day <= lastDayOfTargetMonth ? signupDate.day : lastDayOfTargetMonth;

    return {year: targetYear, month: targetMonth, day: targetDay};
}

// Computes the [periodStart, periodEnd) boundaries and the next billing date for the given cycle number
// of a subscription, anchored on the original signup date so short months and leap-day anniversaries
// never drift, however many cycles have elapsed.
public function getBillingPeriod(CalendarDate subscriptionStart, int cycleNumber) returns BillingPeriod|error {
    if cycleNumber < 1 {
        return error("cycleNumber must be 1 or greater");
    }

    CalendarDate periodStart = addMonthsClamped(subscriptionStart, cycleNumber - 1);
    CalendarDate periodEnd = addMonthsClamped(subscriptionStart, cycleNumber);
    int cycleLengthDays = daysBetween(periodStart, periodEnd);

    return {
        cycleNumber: cycleNumber,
        periodStart: periodStart,
        periodEnd: periodEnd,
        nextBillingDate: periodEnd,
        cycleLengthDays: cycleLengthDays
    };
}

// Prorates a mid-cycle plan change that takes effect on changeDate (inclusive - the new plan applies from
// this date onward) within the given billing period. The credit for the old plan and the charge for the
// new plan are both computed from exact day counts within the cycle, so the amounts always match the
// days the customer actually had on each plan.
public function prorateplanChange(BillingPeriod period, Plan priorPlan, Plan newPlan, CalendarDate changeDate)
        returns ProrationResult|error {
    if daysBetween(period.periodStart, changeDate) < 0 || daysBetween(changeDate, period.periodEnd) <= 0 {
        return error("changeDate must fall within the billing period");
    }

    int daysOnPriorPlan = daysBetween(period.periodStart, changeDate);
    int daysOnNewPlan = daysBetween(changeDate, period.periodEnd);

    decimal dailyPriorRate = priorPlan.monthlyAmount / <decimal>period.cycleLengthDays;
    decimal dailyNewRate = newPlan.monthlyAmount / <decimal>period.cycleLengthDays;

    decimal unusedPriorAmount = dailyPriorRate * <decimal>daysOnNewPlan;
    decimal newPlanAmount = dailyNewRate * <decimal>daysOnNewPlan;

    LineItem priorPlanCredit = {
        kind: PRIOR_PLAN_CREDIT,
        description: string `Credit for unused days on plan ${priorPlan.planId}`,
        periodStart: changeDate,
        periodEnd: period.periodEnd,
        days: daysOnNewPlan,
        amount: -unusedPriorAmount
    };

    LineItem newPlanCharge = {
        kind: NEW_PLAN_CHARGE,
        description: string `Prorated charge for plan ${newPlan.planId}`,
        periodStart: changeDate,
        periodEnd: period.periodEnd,
        days: daysOnNewPlan,
        amount: newPlanAmount
    };

    // The days already spent on the prior plan before changeDate were already charged as part of the
    // regular recurring charge, so only the unused remainder needs to be credited back here.
    decimal netAmount = priorPlanCredit.amount + newPlanCharge.amount;

    return {
        priorPlanCredit: priorPlanCredit,
        newPlanCharge: newPlanCharge,
        netAmount: netAmount
    };
}

// Produces the ordered list of line items for a billing cycle, in the order finance expects to read them:
// any prior-plan credit first, then the new-plan prorated charge, then the regular recurring charge for
// the plan that is active for the remainder/entirety of the cycle. If no plan change occurred, only the
// single recurring charge line item is returned.
public function generateCycleLineItems(BillingPeriod period, Plan activePlan, ProrationResult? proration)
        returns LineItem[] {
    LineItem[] lineItems = [];

    if proration is ProrationResult {
        lineItems.push(proration.priorPlanCredit);
        lineItems.push(proration.newPlanCharge);
    } else {
        LineItem recurringCharge = {
            kind: RECURRING_CHARGE,
            description: string `Monthly charge for plan ${activePlan.planId}`,
            periodStart: period.periodStart,
            periodEnd: period.periodEnd,
            days: period.cycleLengthDays,
            amount: activePlan.monthlyAmount
        };
        lineItems.push(recurringCharge);
    }

    return lineItems;
}
