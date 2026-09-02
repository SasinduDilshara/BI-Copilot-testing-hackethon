// Business/domain types for the SAP Signavio -> Email (SMTP) integration.
// These types represent the P2P (Purchase-to-Pay) process delay monitoring scenario.

# Represents a delayed Purchase-to-Pay process instance extracted from the
# SAP Signavio Process Intelligence "cases" response.
#
# + processName - Business process name (e.g. "Purchase-to-Pay")
# + processInstanceId - Unique identifier of the process instance in Signavio
# + purchaseRequisitionId - Business identifier of the purchase requisition
# + processStatus - Overall status of the process instance (e.g. "Delayed")
# + currentActivity - Activity the case is currently waiting on
# + activityStatus - Status of the current activity (e.g. "Waiting")
# + expectedApprovalHours - Target/expected duration for the approval activity, in hours
# + actualWaitingHours - Actual elapsed time the case has spent in the current activity, in hours
# + delayHours - Computed delay in hours (actualWaitingHours - expectedApprovalHours)
# + responsibleDepartment - Department accountable for the activity
# + responsibleManagerName - Name of the manager who should be notified
# + responsibleManagerEmail - Email address of the manager who should be notified
# + priority - Priority assigned to the notification (e.g. "High")
# + detectedAt - Timestamp at which Signavio detected/reported the delay
public type ProcessDelayInfo record {|
    string processName;
    string processInstanceId;
    string purchaseRequisitionId;
    string processStatus;
    string currentActivity;
    string activityStatus;
    decimal expectedApprovalHours;
    decimal actualWaitingHours;
    decimal delayHours;
    string responsibleDepartment;
    string responsibleManagerName;
    string responsibleManagerEmail;
    string priority;
    string detectedAt;
|};

# Successful end-to-end execution response returned once a notification email
# has been sent for a delayed process instance.
#
# + status - Overall status of the execution, always "SUCCESS"
# + processInstance - Signavio process instance identifier that triggered the notification
# + notificationStatus - Status of the email notification, e.g. "SENT"
# + recipient - Email address the notification was sent to
# + timestamp - Time at which the notification was sent
public type IntegrationSuccessResponse record {|
    string status;
    string processInstance;
    string notificationStatus;
    string recipient;
    string timestamp;
|};

# Response returned when process data was retrieved successfully from Signavio
# but the email notification could not be delivered.
#
# + status - Overall status of the execution, always "PARTIAL_SUCCESS"
# + processInstance - Signavio process instance identifier that triggered the notification
# + signavioStatus - Status of the Signavio retrieval step, always "SUCCESS"
# + notificationStatus - Status of the email notification, always "FAILED"
# + error - Description of the email delivery failure
public type PartialSuccessResponse record {|
    string status;
    string processInstance;
    string signavioStatus;
    string notificationStatus;
    string 'error;
|};

# Response returned when no delayed process instance required a notification
# during a monitoring cycle.
#
# + status - Overall status of the execution, always "SUCCESS"
# + notificationStatus - Status of the notification step, always "NOT_REQUIRED"
# + message - Human readable explanation
public type NoActionResponse record {|
    string status;
    string notificationStatus;
    string message;
|};

# Response returned when the integration cannot complete due to an error
# raised while interacting with SAP Signavio.
#
# + status - Overall status of the execution, always "ERROR"
# + errorCode - Machine readable error code, e.g. "SIGNAVIO_API_ERROR"
# + message - Human readable description of the failure
public type IntegrationErrorResponse record {|
    string status;
    string errorCode;
    string message;
|};

# Union of all possible outcomes of a single monitoring cycle execution.
public type IntegrationResult IntegrationSuccessResponse|PartialSuccessResponse|NoActionResponse|IntegrationErrorResponse;
