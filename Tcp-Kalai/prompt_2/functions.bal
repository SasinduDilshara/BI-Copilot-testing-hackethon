import ballerina/http;

configurable int httpListenerPort = 8081;

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
}
