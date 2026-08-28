import ballerina/log;
import ballerina/time;

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

// Returns the current time formatted as an RFC 3339 timestamp, used to mark when a log event
// was produced by this application (as distinct from the S3-reported event time).
function currentProcessingTimestamp() returns string => time:utcToString(time:utcNow());

// Converts an S3 event record into the log entry representation.
function toS3EventLogEntry(S3EventRecord s3EventRecord, string? messageId) returns S3EventLogEntry => {
    eventType: s3EventRecord.eventName,
    bucketName: s3EventRecord.s3.bucket.name,
    objectKey: s3EventRecord.s3.'object.key,
    eventTime: s3EventRecord.eventTime,
    processingTimestamp: currentProcessingTimestamp(),
    messageId: messageId
};

// Logs that an SQS message has been received and is about to be processed.
function logMessageReceived(string? messageId, int? approximateReceiveCount) {
    MessageReceivedLogEntry logEntry = {
        messageId: messageId,
        approximateReceiveCount: approximateReceiveCount,
        processingTimestamp: currentProcessingTimestamp()
    };
    log:printInfo(logEntry.toJsonString());
}

// Logs that an SQS message could not be parsed/validated as an S3 event notification.
function logValidationFailure(string? messageId, string reason) {
    ValidationFailureLogEntry logEntry = {
        messageId: messageId,
        reason: reason,
        processingTimestamp: currentProcessingTimestamp()
    };
    log:printError(logEntry.toJsonString());
}

// Logs that processing an otherwise valid S3 event notification failed.
function logProcessingFailure(string? messageId, int? approximateReceiveCount, string reason) {
    ProcessingFailureLogEntry logEntry = {
        messageId: messageId,
        approximateReceiveCount: approximateReceiveCount,
        reason: reason,
        processingTimestamp: currentProcessingTimestamp()
    };
    log:printError(logEntry.toJsonString());
}

// Processes the SQS message body by parsing the S3 event notification and logging each record.
// All records in the message must be processed successfully before the caller acknowledges
// (deletes) the message; if any record fails, an error is returned so the whole message remains
// in the queue and is retried by SQS. Records that were already processed previously (duplicate
// delivery or duplicate S3 notification) are detected and skipped without re-triggering any
// downstream action.
function processS3EventMessage(string messageBody, string? messageId) returns error? {
    json|error eventJson = messageBody.fromJsonString();
    if eventJson is error {
        logValidationFailure(messageId, "Message body is not valid JSON: " + eventJson.message());
        return eventJson;
    }

    S3EventNotification|error s3EventNotification = eventJson.cloneWithType();
    if s3EventNotification is error {
        logValidationFailure(messageId, "Message body is not a valid S3 event notification: " +
                s3EventNotification.message());
        return s3EventNotification;
    }

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
