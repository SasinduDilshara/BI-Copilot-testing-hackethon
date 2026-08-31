import ballerina/constraint;

// Represents a device telemetry reading published to a NATS subject of the form
// telemetry.{region}.{siteId}.{deviceType}, e.g. telemetry.eu-west.store-42.fridge
public type DeviceReading record {|
    @constraint:String {minLength: 1}
    string region;
    @constraint:String {minLength: 1}
    string siteId;
    @constraint:String {minLength: 1}
    string deviceType;
    @constraint:String {minLength: 1}
    string metric;
    decimal value;
    // ISO-8601 timestamp string indicating when the reading was taken at the device.
    @constraint:String {minLength: 1}
    string readingAt;
|};

// Represents an alert published to the NATS subject telemetry.alerts when a reading's
// metric value crosses the configured threshold for its device type.
public type TelemetryAlert record {|
    string region;
    string siteId;
    string deviceType;
    string metric;
    decimal value;
    decimal threshold;
    string readingAt;
|};

