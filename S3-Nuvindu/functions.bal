import ballerina/log;

// Converts an S3 event record into the log entry representation.
function toS3EventLogEntry(S3EventRecord s3EventRecord) returns S3EventLogEntry => {
    eventType: s3EventRecord.eventName,
    bucketName: s3EventRecord.s3.bucket.name,
    objectKey: s3EventRecord.s3.'object.key,
    eventTime: s3EventRecord.eventTime
};

// Processes the SQS message body by parsing the S3 event notification and logging each record.
function processS3EventMessage(string messageBody) returns error? {
    json eventJson = check messageBody.fromJsonString();
    S3EventNotification s3EventNotification = check eventJson.cloneWithType();
    foreach S3EventRecord s3EventRecord in s3EventNotification.Records {
        S3EventLogEntry logEntry = toS3EventLogEntry(s3EventRecord);
        log:printInfo(logEntry.toJsonString());
    }
}
