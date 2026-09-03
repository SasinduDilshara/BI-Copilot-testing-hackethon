import ballerina/lang.regexp;
import ballerina/log;
import ballerina/tcp;

configurable int tcpListenerPort = 4040;
configurable string certFile = ?;
configurable string keyFile = ?;

tcp:ListenerSecureSocket deviceTcpListenerSecureSocket = {
    key: {
        certFile: certFile,
        keyFile: keyFile
    }
};

listener tcp:Listener deviceTcpListener = new (tcpListenerPort, secureSocket = deviceTcpListenerSecureSocket);

service on deviceTcpListener {
    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService|tcp:Error? {
        log:printInfo("new tcp connection accepted", remoteHost = caller.remotePort);
        return new DeviceConnectionService(caller);
    }
}

service class DeviceConnectionService {
    *tcp:ConnectionService;

    private boolean handshakeCompleted = false;
    private string deviceId = "";
    private final tcp:Caller deviceCaller;

    function init(tcp:Caller caller) {
        self.deviceCaller = caller;
    }

    remote function onBytes(readonly & byte[] data) returns byte[]|tcp:Error? {
        string|error receivedMessage = string:fromBytes(data);
        if receivedMessage is error {
            log:printWarn("received non-text data, ignoring");
            return;
        }
        if !self.handshakeCompleted {
            self.handleHandshake(receivedMessage);
            return;
        }
        self.handleTelemetry(receivedMessage);
        return;
    }

    private function handleHandshake(string handshakeMessage) {
        string[] handshakeParts = regexp:split(re `\|`, handshakeMessage);
        if handshakeParts.length() != 3 || handshakeParts[0] != "HELLO" {
            log:printWarn("invalid handshake message received", payload = handshakeMessage);
            return;
        }
        string deviceId = handshakeParts[1];
        string deviceType = handshakeParts[2];
        registerDevice(deviceId, deviceType, self.deviceCaller);
        self.deviceId = deviceId;
        self.handshakeCompleted = true;
        log:printInfo("device handshake completed", event = "device_connected", deviceId = deviceId, deviceType = deviceType);
    }

    private function handleTelemetry(string telemetryMessage) {
        string[] telemetryParts = regexp:split(re `\|`, telemetryMessage);
        if telemetryParts.length() != 5 || telemetryParts[0] != "TELEMETRY" {
            log:printWarn("invalid telemetry message received", payload = telemetryMessage);
            return;
        }
        string deviceId = telemetryParts[1];
        string metric = telemetryParts[2];
        string rawValue = telemetryParts[3];
        string unit = telemetryParts[4];
        decimal|error value = decimal:fromString(rawValue);
        if value is error {
            log:printWarn("invalid telemetry value received", payload = telemetryMessage);
            return;
        }
        storeTelemetryReading(deviceId, metric, value, unit);
        touchDeviceLastSeen(deviceId);
    }

    remote function onError(tcp:Error err) returns tcp:Error? {
        string deviceId = self.deviceId;
        if deviceId != "" {
            deregisterDevice(deviceId);
        }
        log:printInfo("device connection error", event = "device_disconnected", deviceId = deviceId, 'error = err);
    }

    remote function onClose() returns tcp:Error? {
        string deviceId = self.deviceId;
        if deviceId != "" {
            deregisterDevice(deviceId);
        }
        log:printInfo("device connection closed", event = "device_disconnected", deviceId = deviceId);
    }
}
