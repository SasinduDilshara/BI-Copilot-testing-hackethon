import ballerina/http;
import ballerinax/gcloud.pubsub;

// Base URL of the Google Cloud Pub/Sub REST API, used for the synchronous
// pull operation that the ballerinax/gcloud.pubsub connector does not expose.
const string PUBSUB_REST_BASE_URL = "https://pubsub.googleapis.com";

// OAuth2 scope required to pull and acknowledge messages via the Pub/Sub
// REST API.
const string PUBSUB_OAUTH_SCOPE = "https://www.googleapis.com/auth/pubsub";

final pubsub:Publisher aggregatePublisher = check initAggregatePublisher();

final http:Client pubsubRestClient = check initPubsubRestClient();

listener http:Listener aggregateServiceListener = new (servicePort);

// Wraps publisher construction in its own function so tests can replace it
// with a mock via @test:Mock, avoiding a real Pub/Sub connection attempt
// during module initialization.
function initAggregatePublisher() returns pubsub:Publisher|error {
    return new (
        topicName,
        projectId = projectId,
        credentials = resolveCredentials(authMode, credentialsPath, credentialsJson)
    );
}

// Wraps REST client construction in its own function so tests can replace it
// with a mock via @test:Mock, avoiding a real Google auth token exchange
// attempt during module initialization.
function initPubsubRestClient() returns http:Client|error {
    ServiceAccountKey serviceAccountKey = check loadServiceAccountKey();
    string assertion = check buildJwtAssertion(serviceAccountKey);

    return new (PUBSUB_REST_BASE_URL,
        auth = {
            tokenUrl: serviceAccountKey.token_uri,
            assertion: assertion,
            scopes: [PUBSUB_OAUTH_SCOPE]
        }
    );
}

// Builds the gcloud.pubsub Credentials record for the given authMode. Pure
// function taking its inputs as parameters so it can be tested directly
// without depending on the module-level configurables.
function resolveCredentials(AuthMode mode, string filePath, string jsonString) returns pubsub:Credentials {
    if mode == "jsonString" {
        return {credentialsJson: jsonString};
    }
    return {credentialsPath: filePath};
}
