import ballerina/lang.regexp;

final regexp:RegExp ackSubjectPattern = re `Re: \[(CRITICAL|WARNING|INFO)\] Incident ([^\s]+)`;

// Extracts the alertId from an acknowledgment email subject line matching
// the pattern "Re: [CRITICAL|WARNING|INFO] Incident {alertId}".
function extractAlertIdFromSubject(string subject) returns string? {
    regexp:Groups? groups = ackSubjectPattern.findGroups(subject);
    if groups is regexp:Groups {
        regexp:Span? alertIdSpan = groups[2];
        if alertIdSpan is regexp:Span {
            return alertIdSpan.substring();
        }
    }
    return ();
}

// Returns the inline HTML colour code for a given alert severity.
function getSeverityColor(Severity severity) returns string {
    if severity == "critical" {
        return "red";
    } else if severity == "warning" {
        return "orange";
    }
    return "blue";
}

// Builds the HTML formatted incident card body for the alert email.
function buildIncidentCardHtml(AlertRequest alertRequest) returns string {
    string severityColor = getSeverityColor(alertRequest.severity);
    string severityUpper = alertRequest.severity.toUpperAscii();
    string htmlBody = string `
        <div style="font-family: Arial, sans-serif; border: 1px solid #ddd; border-radius: 6px; padding: 16px; max-width: 480px;">
            <h2 style="margin-top: 0; color: ${severityColor};">Incident Alert</h2>
            <table style="width: 100%; border-collapse: collapse;">
                <tr>
                    <td style="padding: 6px 8px; font-weight: bold;">Alert ID</td>
                    <td style="padding: 6px 8px;">${alertRequest.alertId}</td>
                </tr>
                <tr>
                    <td style="padding: 6px 8px; font-weight: bold;">Severity</td>
                    <td style="padding: 6px 8px;">
                        <span style="color: #ffffff; background-color: ${severityColor}; padding: 2px 8px; border-radius: 4px;">${severityUpper}</span>
                    </td>
                </tr>
                <tr>
                    <td style="padding: 6px 8px; font-weight: bold;">Service Affected</td>
                    <td style="padding: 6px 8px;">${alertRequest.serviceAffected}</td>
                </tr>
                <tr>
                    <td style="padding: 6px 8px; font-weight: bold;">Description</td>
                    <td style="padding: 6px 8px;">${alertRequest.description}</td>
                </tr>
                <tr>
                    <td style="padding: 6px 8px; font-weight: bold;">Detected At</td>
                    <td style="padding: 6px 8px;">${alertRequest.detectedAt}</td>
                </tr>
                <tr>
                    <td style="padding: 6px 8px; font-weight: bold;">On-call Engineer</td>
                    <td style="padding: 6px 8px;">${alertRequest.oncallEngineerEmail}</td>
                </tr>
            </table>
        </div>
    `;
    return htmlBody;
}
