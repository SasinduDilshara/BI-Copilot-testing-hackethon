// Represents a single aggregate metric value to be published to the
// aggregation topic.
public type AggregateRecord record {|
    string aggregateId;
    string metricName;
    decimal value;
    string periodStart;
    string periodEnd;
|};

// Request body carrying the batch of aggregate records to publish in a
// single call.
public type AggregatePublishRequest record {|
    AggregateRecord[] aggregates;
|};

// Response body returning the broker-assigned message IDs, in the same
// order as the submitted aggregate records.
public type AggregatePublishResponse record {|
    string[] messageIds;
|};
