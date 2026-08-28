import ballerina/log;

// In-memory cache of de-duplication keys for S3 event records that have already been processed
// successfully. This protects against SQS's at-least-once delivery (the same message being
// redelivered) and against S3 occasionally sending the same event notification more than once.
// Note: this cache is process-local and reset on restart. For durability across restarts or
// multiple running instances, back this with a shared store (e.g. a database or distributed
// cache) keyed on the same de-duplication key.
final table<ProcessedEventRecord> key(dedupeKey) processedEvents = table [];

// A minimal marker record used to track de-duplication keys that have already been processed.
type ProcessedEventRecord record {|
    readonly string dedupeKey;
|};

// Builds a stable de-duplication key for an S3 event record. The object's `sequencer` is a
// per-operation token assigned by S3 that uniquely identifies the write/delete that produced
// the event, so it is preferred when present. When absent, the combination of event name,
// bucket, key, and event time is used as a best-effort fallback.
function toDedupeKey(S3EventRecord s3EventRecord) returns string {
    string? sequencer = s3EventRecord.s3.'object?.sequencer;
    if sequencer is string {
        return string:'join(":", s3EventRecord.s3.bucket.name, s3EventRecord.s3.'object.key, sequencer);
    }
    return string:'join(":", s3EventRecord.eventName, s3EventRecord.s3.bucket.name,
            s3EventRecord.s3.'object.key, s3EventRecord.eventTime);
}

// Converts an S3 event record into the log entry representation.
function toS3EventLogEntry(S3EventRecord s3EventRecord, string? messageId) returns S3EventLogEntry => {
    eventType: s3EventRecord.eventName,
    bucketName: s3EventRecord.s3.bucket.name,
    objectKey: s3EventRecord.s3.'object.key,
    eventTime: s3EventRecord.eventTime,
    messageId: messageId
};

// Processes the SQS message body by parsing the S3 event notification and logging each record.
// All records in the message must be processed successfully before the caller acknowledges
// (deletes) the message; if any record fails, an error is returned so the whole message remains
// in the queue and is retried by SQS. Records that were already processed previously (duplicate
// delivery or duplicate S3 notification) are detected and skipped without re-triggering any
// downstream action.
function processS3EventMessage(string messageBody, string? messageId) returns error? {
    json eventJson = check messageBody.fromJsonString();
    S3EventNotification s3EventNotification = check eventJson.cloneWithType();
    foreach S3EventRecord s3EventRecord in s3EventNotification.Records {
        string dedupeKey = toDedupeKey(s3EventRecord);
        if processedEvents.hasKey(dedupeKey) {
            log:printInfo("Skipping already processed S3 event record", dedupeKey = dedupeKey,
                    messageId = messageId);
            continue;
        }

        S3EventLogEntry logEntry = toS3EventLogEntry(s3EventRecord, messageId);
        log:printInfo(logEntry.toJsonString());
        processedEvents.add({dedupeKey});
    }
}
