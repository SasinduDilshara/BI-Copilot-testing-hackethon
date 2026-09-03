import ballerina/http;

configurable int httpListenerPort = 8083;

listener http:Listener deviceHttpListener = new (httpListenerPort);

service /devices on deviceHttpListener {

    resource function get .() returns DeviceStatusInfo[] {
        return getAllDeviceStatuses();
    }

    resource function get [string deviceId]/telemetry() returns TelemetryReading[]|http:NotFound {
        TelemetryReading[]? readings = getDeviceTelemetry(deviceId);
        if readings is () {
            return {
                body: {message: string `no telemetry found for device ${deviceId}`}
            };
        }
        return readings;
    }

    resource function get [string deviceId]/status() returns string|http:NotFound {
        boolean deviceKnown = isDeviceKnown(deviceId);
        if !deviceKnown {
            return {
                body: {message: string `device ${deviceId} not found`}
            };
        }
        boolean online = isDeviceOnline(deviceId);
        return online ? "online" : "offline";
    }
}
