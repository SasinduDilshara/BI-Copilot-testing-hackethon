import ballerina/udp;

// Determines whether a sensor reading is critical based on its type and value.
isolated function isCriticalReading(string sensorType, decimal value) returns boolean {
    if sensorType == "temperature" && value > TEMPERATURE_THRESHOLD {
        return true;
    }
    if sensorType == "pressure" && value > PRESSURE_THRESHOLD {
        return true;
    }
    return false;
}

// Forwards a critical reading to the downstream alert system using a connectionless udp:Client.
function forwardCriticalAlert(string sensorId, string sensorType, decimal value, decimal threshold,
        string detectedAt) returns udp:Error? {
    AlertPayload alertPayload = {
        sensorId,
        sensorType,
        value,
        threshold,
        detectedAt
    };

    udp:Client alertClient = check new (timeout = 5);
    udp:Datagram alertDatagram = {
        remoteHost: ALERT_SYSTEM_HOST,
        remotePort: ALERT_SYSTEM_PORT,
        data: alertPayload.toJsonString().toBytes()
    };
    check alertClient->sendDatagram(alertDatagram);
    check alertClient->close();
}
