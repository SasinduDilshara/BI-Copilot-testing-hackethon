import ballerina/email;
import ballerina/http;
import ballerina/time;

const string OPS_INCIDENTS_EMAIL = "incidents@ops.company.com";

isolated map<boolean> acknowledgedAlerts = {};

service /alerts on new http:Listener(9090) {

    resource function post send(@http:Payload AlertRequest alertRequest) returns AlertResponse|http:InternalServerError {
        string severityUpper = alertRequest.severity.toUpperAscii();
        string subject = string `[${severityUpper}] Incident ${alertRequest.alertId} — ${alertRequest.serviceAffected}`;
        string htmlBody = buildIncidentCardHtml(alertRequest);

        email:Message alertMessage = {
            to: alertRequest.oncallEngineerEmail,
            cc: OPS_INCIDENTS_EMAIL,
            subject: subject,
            htmlBody: htmlBody
        };

        email:Error? sendResult = smtpClient->sendMessage(alertMessage);
        if sendResult is email:Error {
            return {
                body: {
                    message: "Failed to send incident alert email: " + sendResult.message()
                }
            };
        }

        AlertResponse alertResponse = {
            alertId: alertRequest.alertId,
            status: "SENT",
            sentAt: time:utcToString(time:utcNow())
        };
        return alertResponse;
    }

    resource function post poll\-acks() returns AckPollResponse|http:InternalServerError {
        string[] acknowledgedAlertIds = [];

        while true {
            email:Message|email:Error? receiveResult = imapClient->receiveMessage();
            if receiveResult is email:Error {
                email:Error? closeResult = imapClient->close();
                if closeResult is email:Error {
                    return {
                        body: {
                            message: "Failed to close IMAP client: " + closeResult.message()
                        }
                    };
                }
                return {
                    body: {
                        message: "Failed to receive acknowledgment email: " + receiveResult.message()
                    }
                };
            }
            if receiveResult is () {
                break;
            }

            email:Message ackMessage = receiveResult;
            string? alertId = extractAlertIdFromSubject(ackMessage.subject);
            if alertId is string {
                lock {
                    acknowledgedAlerts[alertId] = true;
                }
                acknowledgedAlertIds.push(alertId);
            }
        }

        email:Error? closeResult = imapClient->close();
        if closeResult is email:Error {
            return {
                body: {
                    message: "Failed to close IMAP client: " + closeResult.message()
                }
            };
        }

        AckPollResponse ackPollResponse = {
            processedCount: acknowledgedAlertIds.length(),
            acknowledgedAlertIds: acknowledgedAlertIds
        };
        return ackPollResponse;
    }
}
