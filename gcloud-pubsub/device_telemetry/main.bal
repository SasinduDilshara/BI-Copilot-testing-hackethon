import ballerina/log;

public function main() returns error? {
    DeviceReading reading = {
        deviceId: "device-001",
        site: "site-central",
        metricName: "temperature",
        value: 23.5,
        unit: "C",
        recordedAt: "2026-09-04T09:40:43Z"
    };

    error? result = publishDeviceReading(reading);
    if result is error {
        log:printError("Failed to publish device reading", result);
        return result;
    }
}
