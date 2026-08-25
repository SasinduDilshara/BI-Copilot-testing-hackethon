// Represents the S3 bucket details of an S3 event record.
type S3Bucket record {|
    string name;
|};

// Represents the S3 object details of an S3 event record.
type S3Object record {|
    string 'key;
|};

// Represents the S3 entity details of an S3 event record.
type S3Entity record {|
    S3Bucket bucket;
    S3Object 'object;
|};

// Represents a single S3 event record contained in an S3 event notification.
type S3EventRecord record {|
    string eventName;
    S3Entity s3;
|};

// Represents the S3 event notification payload delivered to the SQS queue.
type S3EventNotification record {|
    S3EventRecord[] Records;
|};

// Represents the structured details extracted from a valid S3 event, used for logging.
type S3EventDetails record {|
    string bucketName;
    string objectKey;
    string eventType;
|};
