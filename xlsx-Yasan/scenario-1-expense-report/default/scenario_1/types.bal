import ballerina/time;

# Allowed expense categories.
public enum ExpenseCategory {
    TRAVEL,
    MEALS,
    ACCOMMODATION,
    SUPPLIES,
    OTHER
}

# A single validated expense entry bound from a data row of the 'Expense Report' sheet.
public type ExpenseEntry record {|
    string employeeId;
    string employeeName;
    string department;
    time:Date expenseDate;
    ExpenseCategory category;
    decimal amountUsd;
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
