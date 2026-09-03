import ballerina/http;
import ballerina/tcp;

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

    resource function post [string deviceId]/command(CommandRequest commandRequest) returns CommandSentResponse|http:ServiceUnavailable|http:InternalServerError {
        CommandRecord?|tcp:Error sendResult = sendCommandToDevice(deviceId, commandRequest.commandType, commandRequest.parameters);
        if sendResult is tcp:Error {
            http:InternalServerError internalServerError = {
                body: {message: string `failed to send command to device ${deviceId}`}
            };
            return internalServerError;
        }
        if sendResult is () {
            DeviceOfflineResponse offlineResponse = {status: "device_offline"};
            http:ServiceUnavailable serviceUnavailable = {
                body: offlineResponse
            };
            return serviceUnavailable;
        }
        CommandRecord sentCommandRecord = sendResult;
        CommandSentResponse commandSentResponse = {
            commandSent: true,
            deviceId: deviceId,
            commandId: sentCommandRecord.commandId
        };
        return commandSentResponse;
    }

    resource function get [string deviceId]/commands() returns CommandRecord[]|http:NotFound {
        boolean deviceKnown = isDeviceKnown(deviceId);
        if !deviceKnown {
            return {
                body: {message: string `device ${deviceId} not found`}
            };
        }
        CommandRecord[]? history = getDeviceCommandHistory(deviceId);
        if history is () {
            return [];
        }
        return history;
    }

    resource function put [string deviceId]/command/[string commandId]/ack() returns CommandAckResponse|http:NotFound {
        boolean acknowledged = acknowledgeCommand(deviceId, commandId);
        if !acknowledged {
            return {
                body: {message: string `command ${commandId} not found for device ${deviceId}`}
            };
        }
        CommandAckResponse ackResponse = {
            acknowledged: true,
            deviceId: deviceId,
            commandId: commandId
        };
        return ackResponse;
    }
}
