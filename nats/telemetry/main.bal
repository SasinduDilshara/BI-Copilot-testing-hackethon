import ballerina/log;
import ballerinax/nats;

// Subscribes to every device subject under telemetry using the '>' wildcard, which matches
// one or more trailing tokens. Readings arrive on subjects such as
// telemetry.eu-west.store-42.fridge (telemetry.{region}.{siteId}.{deviceType}) - since the
// variable part after the 'telemetry' prefix spans multiple tokens, the single-token '*'
// wildcard cannot cover it (it only ever matches exactly one token), so '>' is required to
// catch every device subject, including any deeper subject hierarchies added later.
// The listener is created with validation = true so that each payload is bound to
// DeviceReading and checked against its constraint annotations before onMessage is invoked.
@nats:ServiceConfig {
    subject: "telemetry.>",
    pendingLimits: telemetryPendingLimits
}
service nats:Service on new nats:Listener(natsUrl, connectionName = connectionName, auth = telemetryAuthCredentials,
        secureSocket = telemetrySecureSocket, noEcho = true, validation = true) {

    remote function onMessage(DeviceReading deviceReading) returns error? {
        boolean stale = isStaleReading(deviceReading);
        if stale {
            dropStaleReading(deviceReading);
            return;
        }
        processReading(deviceReading);
    }

    // Handles failures separately based on their cause: malformed/unbindable payloads,
    // constraint validation failures, and any other processing errors.
    remote function onError(nats:AnydataMessage message, nats:Error err) {
        if err is nats:PayloadBindingError {
            log:printError(string `Payload binding failed for subject ${message.subject}`, 'error = err);
        } else if err is nats:PayloadValidationError {
            log:printError(string `Payload constraint validation failed for subject ${message.subject}`, 'error = err);
        } else {
            log:printError(string `Error while processing message on subject ${message.subject}`, 'error = err);
        }
    }
}

