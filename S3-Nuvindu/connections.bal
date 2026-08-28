import ballerinax/aws.sqs;

sqs:ConnectionConfig sqsConnectionConfig = {
    region: "us-east-1",
    auth: {
        accessKeyId: awsAccessKeyId,
        secretAccessKey: awsSecretAccessKey
    }
};

sqs:PollingConfig sqsPollingConfig = {
    pollInterval: 1.0,
    waitTime: 20
};

// Management client used only to provision the dead-letter queue and queue attributes at startup.
final sqs:Client sqsManagementClient = check new (sqsConnectionConfig);

listener sqs:Listener sqsListener = new (sqsConnectionConfig, sqsPollingConfig);
