import ballerina/time;
import ballerina/xlsx;

# Allowed expense categories.
public enum ExpenseCategory {
    TRAVEL,
    MEALS,
    ACCOMMODATION,
    SUPPLIES,
    OTHER
}

# A single expense entry bound directly from a data row of the 'Expense Report' sheet.
# `category` is kept as `string` here so binding never fails on an unrecognized value;
# it is validated against `ExpenseCategory` after binding so the error can report the row/column.
public type ExpenseEntry record {|
    @xlsx:Name {value: "Employee ID"}
    string employeeId;

    @xlsx:Name {value: "Employee Name"}
    string employeeName;

    @xlsx:Name {value: "Department"}
    string department;

    @xlsx:Name {value: "Expense Date"}
    time:Date expenseDate;

    @xlsx:Name {value: "Category"}
    string category;

    @xlsx:Name {value: "Amount (USD)"}
    decimal amountUsd;

    @xlsx:Name {value: "Receipt Attached"}
    boolean receiptAttached;
|};

# Successful upload processing summary.
public type ExpenseUploadSummary record {|
    string reportingPeriod;
    int totalEntries;
    decimal totalAmountUsd;
    map<decimal> perDepartment;
|};

# Details describing exactly which row/column/field failed and why.
public type ExpenseValidationErrorDetails record {
    int rowNumber;
    string column;
    string reason;
};

# Typed error returned when a row fails binding or validation.
public type ExpenseValidationError error<ExpenseValidationErrorDetails>;

# Typed HTTP 400 response body returned when the upload is rejected.
public type ExpenseUploadErrorPayload record {|
    string message;
    int rowNumber;
    string column;
    string reason;
|};
