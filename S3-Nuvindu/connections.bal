import ballerinax/aws.sqs;

sqs:ConnectionConfig sqsConnectionConfig = {
    region: awsRegion,
    auth: {
        accessKeyId: awsAccessKeyId,
        secretAccessKey: awsSecretAccessKey
    }
};

sqs:PollingConfig sqsPollingConfig = {
    pollInterval: sqsPollIntervalSeconds,
    waitTime: sqsWaitTimeSeconds
};

// Management client used only to provision the dead-letter queue and queue attributes at startup.
final sqs:Client sqsManagementClient = check new (sqsConnectionConfig);

listener sqs:Listener sqsListener = new (sqsConnectionConfig, sqsPollingConfig);
