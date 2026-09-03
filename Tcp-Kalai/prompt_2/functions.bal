import ballerina/http;
import ballerina/log;

configurable int httpListenerPort = 8081;
configurable int logShipperListenerPort = 8082;

service /logs on new http:Listener(httpListenerPort) {

    resource function get [string serviceId]() returns LogEntry[] {
        return getLogEntries(serviceId);
    }

    resource function get [string serviceId]/errors() returns LogEntry[] {
        return getErrorLogEntries(serviceId);
    }

    resource function get services() returns string[] {
        return getServiceIds();
    }

    resource function get connections/active() returns ConnectionInfo[] {
        return getActiveConnections();
    }
}

service /ship on new http:Listener(logShipperListenerPort) {

    resource function post log(@http:Payload LogEntry logEntry) returns http:Ok|http:ServiceUnavailable {
        error? shipResult = shipLogEntry(logEntry);
        if shipResult is error {
            log:printError("failed to ship log entry", 'error = shipResult);
            return <http:ServiceUnavailable>{body: "failed to ship log entry to tcp server"};
        }
        return <http:Ok>{body: "log entry shipped successfully"};
    }
}
