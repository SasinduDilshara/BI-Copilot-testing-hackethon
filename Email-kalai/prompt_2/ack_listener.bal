import ballerina/email;
import ballerina/log;
import ballerina/time;

listener email:ImapListener ackImapListener = check new ({
    host: imapListenerHost,
    username: imapListenerUsername,
    password: imapListenerPassword,
    pollingInterval: imapListenerPollingInterval,
    port: imapListenerPort
});

service "ackListener" on ackImapListener {

    remote function onMessage(email:Message emailMessage) {
        string? alertId = extractAlertIdFromSubject(emailMessage.subject);
        if alertId is string {
            lock {
                acknowledgedAlerts[alertId] = true;
            }
            string fromAddress = emailMessage?.'from ?: "";
            log:printInfo("alert acknowledged",
                event = "alert_acknowledged",
                alertId = alertId,
                'from = fromAddress,
                receivedAt = time:utcToString(time:utcNow())
            );
        }
    }

    remote function onError(email:Error emailError) {
        log:printError("Error while polling for acknowledgment emails", 'error = emailError);
    }
}
