import ballerina/lang.value;
import ballerina/log;
import ballerina/tcp;

configurable int tcpListenerPort = 5140;

service tcp:Service on new tcp:Listener(tcpListenerPort) {

    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService {
        log:printInfo("client connected", remotePort = caller.remotePort);
        return new LogConnectionService();
    }
}

service class LogConnectionService {
    *tcp:ConnectionService;

    private string? serviceId = ();

    remote function onBytes(readonly & byte[] data) returns byte[]|tcp:Error? {
        string|error logLine = string:fromBytes(data);
        if logLine is error {
            log:printError("failed to decode log line", 'error = logLine);
            return ();
        }

        LogEntry|error logEntry = value:fromJsonStringWithType(logLine);
        if logEntry is error {
            log:printError("failed to parse log entry", 'error = logEntry);
            return ();
        }

        self.serviceId = logEntry.serviceId;
        addLogEntry(logEntry);

        return "OK\n".toBytes();
    }

    remote function onError(tcp:Error err) returns tcp:Error? {
        string? serviceId = self.serviceId;
        if serviceId is string {
            log:printError("tcp connection error", event = "log_stream_error", serviceId = serviceId, 'error = err);
        } else {
            log:printError("tcp connection error", event = "log_stream_error", 'error = err);
        }
    }

    remote function onClose() returns tcp:Error? {
        string? serviceId = self.serviceId;
        if serviceId is string {
            log:printInfo("tcp connection closed", event = "log_stream_closed", serviceId = serviceId);
        } else {
            log:printInfo("tcp connection closed", event = "log_stream_closed");
        }
    }
}
