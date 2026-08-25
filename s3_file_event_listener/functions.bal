import ballerina/log;

// Parses the SQS message body as an S3 event notification and logs a structured
// message for each valid S3 event record found within it.
function processS3EventMessage(string? messageBody) returns error? {
    if messageBody is () {
        log:printWarn("Received an empty message body, skipping");
        return;
    }

    json eventJson = check messageBody.fromJsonString();
    S3EventNotification|error s3EventNotification = eventJson.cloneWithType();
    if s3EventNotification is error {
        log:printWarn("Skipping message that does not contain a valid S3 event notification",
                messageBody = messageBody);
        return;
    }

    S3EventRecord[] s3EventRecords = s3EventNotification.Records;
    foreach S3EventRecord s3EventRecord in s3EventRecords {
        S3EventDetails s3EventDetails = {
            bucketName: s3EventRecord.s3.bucket.name,
            objectKey: s3EventRecord.s3.'object.'key,
            eventType: s3EventRecord.eventName
        };
        log:printInfo("S3 event received", bucketName = s3EventDetails.bucketName,
                objectKey = s3EventDetails.objectKey, eventType = s3EventDetails.eventType);
    }
}
