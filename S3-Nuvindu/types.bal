// Represents the S3 bucket details within an S3 event record.
public type S3Bucket record {
    string name;
};

// Represents the S3 object details within an S3 event record.
public type S3Object record {
    string key;
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

// Represents the log entry produced for each processed S3 event record.
public type S3EventLogEntry record {|
    string eventType;
    string bucketName;
    string objectKey;
    string eventTime;
|};
