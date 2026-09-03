import ballerina/udp;

// Determines whether a sensor reading is critical based on its type and value.
isolated function isCriticalReading(string sensorType, decimal value) returns boolean {
    if sensorType == "temperature" && value > temperatureThreshold {
        return true;
    }
    if sensorType == "pressure" && value > pressureThreshold {
        return true;
    }
    return false;
}

// Records a critical alert event in the alert history, keeping only the last 100 entries.
isolated function recordAlertEvent(string sensorId, string sensorType, decimal value, string detectedAt) {
    AlertEvent event = {
        sensorId,
        sensorType,
        value,
        detectedAt,
        acknowledged: false
    };
    lock {
        alertHistory.push(event.clone());
        if alertHistory.length() > 100 {
            _ = alertHistory.shift();
        }
    }
}

// Marks the latest alert event for the given sensor as acknowledged. Returns true if an event was found and updated.
isolated function acknowledgeLatestAlert(string sensorId) returns boolean {
    lock {
        int lastIndex = alertHistory.length() - 1;
        foreach int i in 0 ..< alertHistory.length() {
            int currentIndex = lastIndex - i;
            if alertHistory[currentIndex].sensorId == sensorId {
                alertHistory[currentIndex].acknowledged = true;
                return true;
            }
        }
        return false;
    }
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
