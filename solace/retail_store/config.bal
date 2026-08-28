// Solace PubSub+ broker connection configuration.
configurable string solaceBrokerUrl = ?;
configurable string solaceVpnName = ?;

// Basic authentication credentials for the broker connection.
configurable string solaceUsername = ?;
configurable string solacePassword = ?;

// Durable topic endpoint configuration for the store telemetry subscription.
// The topic uses the `*` single-level wildcard for the region, storeId and deviceType
// segments so that telemetry from every store and device is matched:
//   retail/telemetry/*/*/*
//   - segment 1 `*` matches any region (e.g. "us-east", "eu-west")
//   - segment 2 `*` matches any storeId (e.g. "store-042")
//   - segment 3 `*` matches any deviceType (e.g. "fridge", "pos", "hvac")
configurable string telemetryTopicName = "retail/telemetry/*/*/*";
configurable string telemetryEndpointName = "RETAIL.TELEMETRY.DTE";

// HTTP listener configuration.
configurable int servicePort = 8092;

// Alerting configuration: published with DIRECT (at-most-once) delivery, a short time-to-live
// and top priority so that alerts are not queued behind routine telemetry traffic.
configurable decimal alertTimeToLive = 30.0;
configurable int alertPriority = 9;

// Per-device-type alert thresholds. A reading whose metric value exceeds the threshold
// configured for its deviceType triggers an alert.
configurable map<decimal> deviceTypeThresholds = {
    "fridge": 8.0,
    "hvac": 30.0,
    "pos": 100.0
};

// Bounded in-memory buffer configuration for telemetry readings awaiting downstream processing.
// When the buffer is full, the oldest buffered reading is shed to make room for the newest one
// (shed-oldest backpressure) rather than blocking or rejecting the newest reading.
configurable int telemetryBufferCapacity = 100;

// Per-region allow list. Telemetry readings originating from a region not on this list are
// dropped and counted instead of being buffered/processed.
configurable string[] allowedRegions = ["us-east", "us-west", "eu-west"];

