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

listener sqs:Listener sqsListener = new (sqsConnectionConfig, sqsPollingConfig);
