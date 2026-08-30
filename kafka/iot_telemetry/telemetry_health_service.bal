import ballerina/http;

listener http:Listener telemetryHealthListener = new (telemetryHealthServicePort);

service /telemetry on telemetryHealthListener {

    // Reports the alert buffer's current occupancy, capacity, and the total
    // number of alerts dropped (shed) since startup because the buffer was
    // full.
    resource function get health() returns AlertBufferHealth {
        return alertBuffer.getHealth();
    }
}
