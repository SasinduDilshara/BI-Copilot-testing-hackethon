// Entry point for the SAP Signavio -> Email (SMTP) delayed-approval
// notification integration.
//
// This automation periodically polls SAP Signavio for Purchase-to-Pay process
// instances that have exceeded the Manager Approval time threshold and sends
// an email notification to the responsible procurement manager.

import ballerina/email;
import ballerina/lang.runtime;
import ballerina/log;
import ballerinax/sap.signavio;

public function main() returns error? {
    log:printInfo("Starting SAP Signavio Purchase-to-Pay delay monitoring integration",
        pollingIntervalSeconds = pollingIntervalSeconds, approvalThresholdHours = approvalThresholdHours);

    signavio:Client signavioClient = check getSignavioClient();
    email:SmtpClient smtpClient = check getSmtpClient();

    while true {
        IntegrationResult result = runMonitoringCycle(signavioClient, smtpClient);
        log:printInfo("Monitoring cycle completed", result = result.toString());
        runtime:sleep(pollingIntervalSeconds);
    }
}
