import ballerinax/gcloud.pubsub;

final pubsub:Publisher telemetryPublisher = check new (
    topicName,
    projectId = projectId,
    credentials = {
        credentialsPath: credentialsPath
    },
    enableBatching = true,
    batchSettings = {
        elementCountThreshold: batchElementCountThreshold,
        requestByteSizeThreshold: batchByteSizeThreshold,
        delayThresholdMillis: batchDelayThresholdMillis
    }
);
