// Represents the S3 bucket details within an S3 event record.
public type S3Bucket record {
    string name;
};

// Represents the S3 object details within an S3 event record.
public type S3Object record {
    string key;
    // Unique per-operation token assigned by S3, used to build a stable de-duplication key.
    string sequencer?;
};

// Represents the S3 entity (bucket and object) within an S3 event record.
public type S3Entity record {
    S3Bucket bucket;
    S3Object 'object;
};

// Represents a single record within an S3 event notification.
public type S3EventRecord record {
    string eventTime;
    string eventName;
    S3Entity s3;
};

// Represents the overall S3 event notification payload received via SQS.
public type S3EventNotification record {
    S3EventRecord[] Records;
};

// Represents the structured log entry produced when an SQS message is received, before any
// parsing or processing has taken place.
public type MessageReceivedLogEntry record {|
    string logType = "MESSAGE_RECEIVED";
    string? messageId;
    int? approximateReceiveCount;
    string processingTimestamp;
|};

// Represents the structured log entry produced for each S3 event record that was processed
// successfully.
public type S3EventLogEntry record {|
    string logType = "S3_EVENT_PROCESSED";
    string eventType;
    string bucketName;
    string objectKey;
    string eventTime;
    string processingTimestamp;
    // Correlation identifier for the SQS message that carried this event, to trace failures and retries.
    string? messageId;
|};

// Represents the structured log entry produced when an SQS message body cannot be parsed as a
// valid S3 event notification.
public type ValidationFailureLogEntry record {|
    string logType = "VALIDATION_FAILURE";
    string? messageId;
    string reason;
    string processingTimestamp;
|};

// Represents the structured log entry produced when processing an otherwise valid S3 event
// notification fails (e.g. a downstream error), so the message is left in the queue for retry.
public type ProcessingFailureLogEntry record {|
    string logType = "PROCESSING_FAILURE";
    string? messageId;
    int? approximateReceiveCount;
    string reason;
    string processingTimestamp;
|};
