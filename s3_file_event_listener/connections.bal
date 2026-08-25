import ballerinax/aws;
import ballerinax/aws.sqs;

sqs:PollingConfig pollingConfig = {
    pollInterval: 1.0,
    waitTime: 20
};

sqs:ConnectionConfig connectionConfig = {
    region: aws:US_EAST_1,
    auth: {
        accessKeyId,
        secretAccessKey
    }
};

listener sqs:Listener sqsListener = new (connectionConfig, pollingConfig);
