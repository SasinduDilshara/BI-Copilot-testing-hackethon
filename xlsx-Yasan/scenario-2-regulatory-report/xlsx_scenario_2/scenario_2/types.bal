import ballerina/time;

# Region where the alert was raised.
public enum Region {
    APAC,
    EMEA,
    AMER
}

# Type of the suspicious activity alert.
public enum AlertType {
    STRUCTURING,
    VELOCITY,
    SANCTIONS_HIT,
    MANUAL
}

# Current status of the alert.
public enum AlertStatus {
    OPEN,
    ESCALATED,
    CLOSED
}

# Represents a single suspicious transaction alert record.
public type TransactionAlert record {|
    string alertId;
    string branchCode;
    Region region;
    AlertType alertType;
    decimal amountUsd;
    time:Date raisedOn;
    AlertStatus status;
|};

# Request body for the report generation endpoint.
public type GenerateReportRequest record {|
    string month;
    string outputPath;
|};

# Successful report generation response.
public type GenerateReportResponse record {|
    string message;
    string outputPath;
    string month;
    int totalAlerts;
|};

# Row shape written to the 'Summary' sheet.
public type RegionSummaryRow record {|
    string region;
    int alertCount;
    decimal totalFlaggedAmountUsd;
|};

# Row shape written to the consolidated 'Alerts' sheet/table. Includes the region column so a
# single table can hold alerts across all regions.
public type AlertRow record {|
    string alertId;
    string branchCode;
    string region;
    string alertType;
    decimal amountUsd;
    time:Date raisedOn;
    string status;
|};

# Generic error message payload used for error responses.
public type ErrorMessage record {|
    string message;
|};

# Metadata describing the consolidated alerts Excel table within the workbook.
public type AlertsTableInfo record {|
    string tableName;
    string[] headers;
    int rowCount;
    string dataRange;
    boolean hasTotalsRow;
    boolean hasStrayRowsBelowTable;
|};

# Response body for the workbook verification endpoint.
public type VerifyReportResponse record {|
    string workbookPath;
    AlertsTableInfo alertsTable;
|};
