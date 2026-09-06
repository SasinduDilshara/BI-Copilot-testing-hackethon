import ballerina/crypto;
import ballerina/io;
import ballerina/jwt;
import ballerina/log;
import ballerinax/gcloud.pubsub;

// Builds the Pub/Sub message for a single aggregate record, carrying the
// whole record as the JSON payload body.
function buildAggregateMessage(AggregateRecord aggregate) returns pubsub:Message => {
    data: aggregate.toJsonString().toBytes()
};

// Publishes a batch of aggregate records to the configured Pub/Sub topic in
// a single call and returns the broker-assigned message IDs in the same
// order as the submitted records.
function publishAggregateBatch(AggregateRecord[] aggregates) returns string[]|error {
    pubsub:Message[] messages = from AggregateRecord aggregate in aggregates
        select buildAggregateMessage(aggregate);

    string[] messageIds = check aggregatePublisher->publishBatch(messages);
    log:printInfo("Published aggregate record batch", batchSize = messageIds.length());
    return messageIds;
}

// Loads the service account key from whichever source authMode selects, and
// parses out the fields needed to build a self-signed JWT.
function loadServiceAccountKey() returns ServiceAccountKey|error {
    string keyJsonText;
    if authMode == "jsonString" {
        keyJsonText = credentialsJson;
    } else {
        keyJsonText = check io:fileReadString(credentialsPath);
    }
    return keyJsonText.fromJsonStringWithType(ServiceAccountKey);
}

// Builds a self-signed JWT assertion for the Google OAuth2 JWT-bearer grant,
// signed with the service account's RSA private key, granting the Pub/Sub
// scope required to pull and acknowledge messages.
function buildJwtAssertion(ServiceAccountKey serviceAccountKey) returns string|error {
    // JSON parsing (fromJsonStringWithType) already unescapes the "\n"
    // sequences in the private_key field into real newline characters, so
    // the PEM content here is ready to decode directly.
    crypto:PrivateKey privateKey =
        check crypto:decodeRsaPrivateKeyFromContent(serviceAccountKey.private_key.toBytes());

    jwt:IssuerConfig issuerConfig = {
        issuer: serviceAccountKey.client_email,
        audience: serviceAccountKey.token_uri,
        expTime: 3600,
        customClaims: {
            "scope": PUBSUB_OAUTH_SCOPE
        },
        signatureConfig: {
            algorithm: jwt:RS256,
            config: privateKey
        }
    };
    return jwt:issue(issuerConfig);
}

// Pulls up to pullMaxMessages messages synchronously from the configured
// subscription via the Pub/Sub REST API, for operational spot checks.
function pullAggregateMessages() returns PulledMessage[]|error {
    string subscriptionPath = string `projects/${projectId}/subscriptions/${subscriptionName}`;
    json requestBody = {
        maxMessages: pullMaxMessages
    };

    string pullPath = string `/v1/${subscriptionPath}:pull`;
    PubSubPullResponse pullResponse =
        check pubsubRestClient->post(pullPath, requestBody, targetType = PubSubPullResponse);

    PulledMessage[] pulledMessages = from PubSubReceivedMessage received in pullResponse.receivedMessages
        select toPulledMessage(received);

    log:printInfo("Pulled messages from subscription", subscriptionName = subscriptionName,
            pulledCount = pulledMessages.length());
    return pulledMessages;
}

// Converts a REST API received-message entry into a PulledMessage, decoding
// the base64-encoded payload data.
function toPulledMessage(PubSubReceivedMessage received) returns PulledMessage => {
    ackId: received.ackId,
    messageId: received.message.messageId,
    data: received.message.data,
    attributes: received.message.attributes,
    publishTime: received.message.publishTime
};
