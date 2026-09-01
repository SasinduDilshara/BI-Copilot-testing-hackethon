import ballerina/log;
import ballerina/udp;

const string ALERT_SYSTEM_HOST = "alert-system.internal";
const int ALERT_SYSTEM_PORT = 9999;

service on new udp:Listener(9000) {

    remote function onDatagram(readonly & udp:Datagram datagram, udp:Caller caller) returns udp:Error? {
        byte[] data = datagram.data;
        string|error payload = string:fromBytes(data);
        if payload is error {
            log:printError("failed to decode datagram payload", event = "sensor_read_error");
            return;
        }

        string:RegExp delimiterPattern = re `\|`;
        string[] fields = delimiterPattern.split(payload);
        if fields.length() != 5 {
            log:printError("invalid payload format: " + payload, event = "sensor_read_error");
            return;
        }

        string sensorId = fields[0];
        string sensorType = fields[1];
        decimal|error value = decimal:fromString(fields[2]);
        if value is error {
            log:printError("invalid value field: " + fields[2], event = "sensor_read_error");
            return;
        }
        string unit = fields[3];
        string timestamp = fields[4];

        SensorReading reading = {
            sensorId,
            sensorType,
            value,
            unit,
            timestamp
        };

        lock {
            sensorReadings[sensorId] = reading.clone();
        }

        if isCriticalReading(sensorType, value) {
            decimal threshold = sensorType == "temperature" ? temperatureThreshold : pressureThreshold;
            check forwardCriticalAlert(sensorId, sensorType, value, threshold, timestamp);
            recordAlertEvent(sensorId, sensorType, value, timestamp);
        }

        string ackMessage = string `ACK|${sensorId}|${timestamp}`;
        udp:Datagram ackDatagram = {
            remoteHost: datagram.remoteHost,
            remotePort: datagram.remotePort,
            data: ackMessage.toBytes()
        };
        check caller->sendDatagram(ackDatagram);
    }

    remote function onError(readonly & udp:Error err) {
        log:printError(err.message(), event = "sensor_read_error");
    }
}
