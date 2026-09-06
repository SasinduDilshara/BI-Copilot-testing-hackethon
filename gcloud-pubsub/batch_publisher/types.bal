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

// Selects how the service account key material is supplied. "filePath" reads
// the key from a file on disk; "jsonString" takes the whole key as an
// in-memory JSON string, for environments with no writable/readable service
// account file (e.g. secrets injected purely as environment variables).
public type AuthMode "filePath"|"jsonString";

// A single message pulled synchronously from a Pub/Sub subscription, for
// operational spot checks.
public type PulledMessage record {|
    string ackId;
    string? messageId;
    string data;
    map<string> attributes;
    string? publishTime;
|};

// Response body returning the messages pulled from the subscription.
public type AggregatePullResponse record {|
    PulledMessage[] messages;
|};

// The subset of a Google service account key file/JSON needed to build a
// self-signed JWT for the JWT-bearer OAuth2 grant used by the Pub/Sub REST
// pull API.
type ServiceAccountKey record {|
    string client_email;
    string private_key;
    string token_uri;
|};

// A single received message entry as returned by the Pub/Sub REST
// projects.subscriptions.pull API.
type PubSubReceivedMessage record {|
    string ackId;
    PubSubRestMessage message;
|};

// The message body nested inside a received message entry from the Pub/Sub
// REST pull API. The data field is base64-encoded by the broker.
type PubSubRestMessage record {|
    string? messageId = ();
    string data = "";
    map<string> attributes = {};
    string? publishTime = ();
|};

// The response body of the Pub/Sub REST projects.subscriptions.pull API.
type PubSubPullResponse record {|
    PubSubReceivedMessage[] receivedMessages = [];
|};
