// Business rule evaluation and email construction helpers for the
// SAP Signavio -> Email (SMTP) delayed-approval notification integration.

import ballerina/email;
import ballerina/log;
import ballerina/time;

# Business rule:
# "If a Purchase-to-Pay process instance has remained in the Manager Approval
# activity for more than the configured threshold (default 24 hours),
# a high-priority email notification must be sent to the responsible manager."
#
# + delayInfo - The process delay information extracted from Signavio
# + return - true if a notification must be sent for this process instance
function requiresNotification(ProcessDelayInfo delayInfo) returns boolean {
    boolean isManagerApprovalActivity = delayInfo.currentActivity == "Manager Approval";
    boolean isWaiting = delayInfo.activityStatus == "Waiting";
    boolean exceedsThreshold = delayInfo.actualWaitingHours > approvalThresholdHours;
    return isManagerApprovalActivity && isWaiting && exceedsThreshold;
}

# Formats an ISO-8601 timestamp (e.g. "2026-09-02T10:00:00+05:30") into a
# human readable date/time string (e.g. "02 September 2026, 10:00 AM").
#
# + isoTimestamp - The ISO-8601 timestamp to format
# + return - A human readable representation, or the original value if parsing fails
function formatDetectionTime(string isoTimestamp) returns string {
    time:Utc|time:Error utc = time:utcFromString(isoTimestamp);
    if utc is time:Error {
        return isoTimestamp;
    }
    time:Civil civil = time:utcToCivil(utc);
    string[] monthNames = ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"];
    int monthIndex = civil.month - 1;
    string monthName = monthNames[monthIndex];
    int hour24 = civil.hour;
    string meridiem = hour24 >= 12 ? "PM" : "AM";
    int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    string minuteStr = civil.minute < 10 ? "0" + civil.minute.toString() : civil.minute.toString();
    string dayStr = civil.day < 10 ? "0" + civil.day.toString() : civil.day.toString();
    return string `${dayStr} ${monthName} ${civil.year}, ${hour12}:${minuteStr} ${meridiem}`;
}

# Builds the notification email subject for a delayed process instance.
#
# + delayInfo - The process delay information
# + return - The email subject line
function buildEmailSubject(ProcessDelayInfo delayInfo) returns string =>
    string `URGENT: Purchase-to-Pay Approval Delayed \u2013 ${delayInfo.purchaseRequisitionId}`;

# Builds the notification email body for a delayed process instance.
#
# + delayInfo - The process delay information
# + return - The plain text email body
function buildEmailBody(ProcessDelayInfo delayInfo) returns string {
    string formattedDetectedAt = formatDetectionTime(delayInfo.detectedAt);
    string firstName = extractFirstName(delayInfo.responsibleManagerName);
    return string `Dear ${firstName},

A delayed Purchase-to-Pay process instance has been detected in SAP Signavio.

Process: ${delayInfo.processName}
Process Instance: ${delayInfo.processInstanceId}
Purchase Requisition: ${delayInfo.purchaseRequisitionId}
Current Activity: ${delayInfo.currentActivity}
Expected Approval Time: ${delayInfo.expectedApprovalHours} hours
Actual Waiting Time: ${delayInfo.actualWaitingHours} hours
Delay: ${delayInfo.delayHours} hours
Priority: ${delayInfo.priority}
Detected At: ${formattedDetectedAt}

Please review the process instance in SAP Signavio and take the necessary action to prevent further delays.

Regards,
Process Monitoring System`;
}

# Extracts the first name from a full name string (e.g. "John Perera" -> "John").
#
# + fullName - The full name of the responsible manager
# + return - The first name, or the full name if it cannot be split
function extractFirstName(string fullName) returns string {
    string:RegExp whitespacePattern = re `\s+`;
    string[] parts = whitespacePattern.split(fullName.trim());
    if parts.length() == 0 {
        return fullName;
    }
    return parts[0];
}

# Sends the delayed-process notification email through the given SMTP client.
#
# + delayInfo - The process delay information to notify about
# + smtp - The SMTP client to use for sending the notification
# + return - An email:Error if the delivery fails, otherwise nil
function sendDelayNotificationEmail(ProcessDelayInfo delayInfo, email:SmtpClient smtp) returns email:Error? {
    string subject = buildEmailSubject(delayInfo);
    string body = buildEmailBody(delayInfo);
    email:Message notificationMessage = {
        to: delayInfo.responsibleManagerEmail,
        subject: subject,
        body: body,
        'from: smtpUsername
    };
    email:Error? sendResult = smtp->sendMessage(notificationMessage);
    if sendResult is email:Error {
        log:printError("Failed to send delay notification email",
            'error = sendResult, processInstance = delayInfo.processInstanceId);
        return sendResult;
    }
    log:printInfo("Delay notification email sent successfully",
        processInstance = delayInfo.processInstanceId, recipient = delayInfo.responsibleManagerEmail);
    return;
}
