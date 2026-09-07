import ballerina/crypto;
import ballerina/http;
import ballerina/lang.runtime;
import ballerina/test;
import ballerina/websubhub;

const string TEST_CALLBACK = "http://localhost:9210/callback";
const string DISALLOWED_CALLBACK = "http://disallowed-host.example.com:9999/callback";
const string UNKNOWN_TOPIC = "http://localhost:9200/inventory/updates/unknown-topic";
const string WRONG_SECRET = "wrong-secret-value";

final http:Client hubHttpClient = check new (string `http://localhost:${hubPort.toString()}/websubhub`);
final websubhub:PublisherClient testPublisherClient = check new (hubUrl);

// In-memory store of content distribution notifications received by the mock subscriber callback.
map<json[]> receivedNotifications = {};

// In-memory store of signature validity results per received notification.
map<boolean[]> receivedSignatureValidity = {};

@test:BeforeSuite
function beforeSuite() returns error? {
    // Allow time for the hub and publisher listeners declared in main.bal to fully start.
    runtime:sleep(3);
}

// Plain HTTP mock callback service acting as a WebSub subscriber. This allows testing
// websubhub content distribution, including signature verification, without importing ballerina/websub.
service /callback on new http:Listener(9210) {

    resource function post .(http:Request request) returns http:Ok|error {
        byte[] rawPayload = check request.getBinaryPayload();
        string|http:HeaderNotFoundError signatureHeader = request.getHeader("X-Hub-Signature");
        string expectedSignature = check computeContentSignature(rawPayload, subscriptionSecret);
        boolean signatureValid = signatureHeader is string && crypto:equalConstantTime(signatureHeader, expectedSignature);

        string rawPayloadText = check string:fromBytes(rawPayload);
        json content = check rawPayloadText.fromJsonString();

        json[] existingNotifications = receivedNotifications[TEST_CALLBACK] ?: [];
        existingNotifications.push(content);
        receivedNotifications[TEST_CALLBACK] = existingNotifications;

        boolean[] existingValidity = receivedSignatureValidity[TEST_CALLBACK] ?: [];
        existingValidity.push(signatureValid);
        receivedSignatureValidity[TEST_CALLBACK] = existingValidity;
        return {body: "notified"};
    }
}

@test:Config {}
function testTopicRegistration() returns error? {
    websubhub:TopicRegistrationSuccess result = check testPublisherClient->registerTopic(topicUrl);
    test:assertEquals(result.statusCode, http:STATUS_OK, msg = "Topic registration should succeed");
}

@test:Config {
    dependsOn: [testTopicRegistration]
}
function testDuplicateTopicRegistrationFails() returns error? {
    websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError result =
        testPublisherClient->registerTopic(topicUrl);
    test:assertTrue(result is websubhub:TopicRegistrationError, msg = "Duplicate topic registration should fail");
}

@test:Config {
    dependsOn: [testTopicRegistration]
}
function testSubscriptionToUnknownTopicIsDenied() returns error? {
    string formPayload = string `hub.mode=subscribe&hub.topic=${UNKNOWN_TOPIC}&hub.callback=${TEST_CALLBACK}&hub.secret=${subscriptionSecret}&hub.lease_seconds=${leaseSeconds.toString()}`;
    http:Response response = check hubHttpClient->post("", formPayload, mediaType = "application/x-www-form-urlencoded");
    test:assertEquals(response.statusCode, http:STATUS_NOT_FOUND, msg = "Subscription to an unknown topic should be denied");

    string key = subscriptionKey(UNKNOWN_TOPIC, TEST_CALLBACK);
    test:assertFalse(verifiedSubscriptions.hasKey(key), msg = "Subscription to an unknown topic should not be tracked as verified");
}

@test:Config {
    dependsOn: [testTopicRegistration]
}
function testSubscriptionWithDisallowedCallbackHostIsDenied() returns error? {
    string formPayload = string `hub.mode=subscribe&hub.topic=${topicUrl}&hub.callback=${DISALLOWED_CALLBACK}&hub.secret=${subscriptionSecret}&hub.lease_seconds=${leaseSeconds.toString()}`;
    http:Response response = check hubHttpClient->post("", formPayload, mediaType = "application/x-www-form-urlencoded");
    test:assertEquals(response.statusCode, http:STATUS_FORBIDDEN, msg = "Subscription with a disallowed callback host should be denied");

    string key = subscriptionKey(topicUrl, DISALLOWED_CALLBACK);
    test:assertFalse(verifiedSubscriptions.hasKey(key), msg = "Subscription with a disallowed callback host should not be tracked as verified");
}

@test:Config {
    dependsOn: [testTopicRegistration]
}
function testSubscriptionWithMissingSecretIsDenied() returns error? {
    string formPayload = string `hub.mode=subscribe&hub.topic=${topicUrl}&hub.callback=${TEST_CALLBACK}&hub.lease_seconds=${leaseSeconds.toString()}`;
    http:Response response = check hubHttpClient->post("", formPayload, mediaType = "application/x-www-form-urlencoded");
    test:assertEquals(response.statusCode, http:STATUS_UNAUTHORIZED, msg = "Subscription with a missing secret should be denied");

    string key = subscriptionKey(topicUrl, TEST_CALLBACK);
    test:assertFalse(verifiedSubscriptions.hasKey(key), msg = "Subscription with a missing secret should not be tracked as verified");
}

@test:Config {
    dependsOn: [testTopicRegistration]
}
function testSubscriptionWithIncorrectSecretIsDenied() returns error? {
    string formPayload = string `hub.mode=subscribe&hub.topic=${topicUrl}&hub.callback=${TEST_CALLBACK}&hub.secret=${WRONG_SECRET}&hub.lease_seconds=${leaseSeconds.toString()}`;
    http:Response response = check hubHttpClient->post("", formPayload, mediaType = "application/x-www-form-urlencoded");
    test:assertEquals(response.statusCode, http:STATUS_UNAUTHORIZED, msg = "Subscription with an incorrect secret should be denied");

    string key = subscriptionKey(topicUrl, TEST_CALLBACK);
    test:assertFalse(verifiedSubscriptions.hasKey(key), msg = "Subscription with an incorrect secret should not be tracked as verified");
}

@test:Config {
    dependsOn: [testTopicRegistration]
}
function testSubscriptionVerification() returns error? {
    string formPayload = string `hub.mode=subscribe&hub.topic=${topicUrl}&hub.callback=${TEST_CALLBACK}&hub.secret=${subscriptionSecret}&hub.lease_seconds=${leaseSeconds.toString()}`;
    http:Response response = check hubHttpClient->post("", formPayload, mediaType = "application/x-www-form-urlencoded");
    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Subscription request should be accepted");

    // Allow time for the automatic intent verification to complete asynchronously.
    runtime:sleep(2);
    string key = subscriptionKey(topicUrl, TEST_CALLBACK);
    test:assertTrue(verifiedSubscriptions.hasKey(key), msg = "Subscription should be tracked as verified in-memory");
}

@test:Config {
    dependsOn: [testSubscriptionVerification]
}
function testPublicationAndDelivery() returns error? {
    StockUpdate stockUpdate = {
        eventId: "evt-001",
        sku: "SKU-1234",
        warehouseId: "WH-01",
        availableQuantity: 150,
        occurredAt: "2026-09-07T08:00:00Z"
    };
    http:Client publisherHttpClient = check new (string `http://localhost:${publisherPort.toString()}`);
    http:Response response = check publisherHttpClient->post("/inventory/updates", stockUpdate);
    test:assertEquals(response.statusCode, http:STATUS_OK, msg = "Publishing stock update should succeed");

    // Allow time for the hub to deliver the content to the verified subscriber.
    runtime:sleep(2);
    json[] notifications = receivedNotifications[TEST_CALLBACK] ?: [];
    test:assertTrue(notifications.length() > 0, msg = "Subscriber callback should have received the content distribution");

    json lastNotification = notifications[notifications.length() - 1];
    map<json> lastNotificationMap = check lastNotification.ensureType();
    test:assertEquals(lastNotificationMap["eventId"], "evt-001", msg = "Delivered content should match the published stock update");

    boolean[] signatureValidities = receivedSignatureValidity[TEST_CALLBACK] ?: [];
    test:assertTrue(signatureValidities.length() > 0, msg = "Signature validity should have been recorded for the delivery");
    test:assertTrue(signatureValidities[signatureValidities.length() - 1], msg = "Delivered content should be signed with the configured subscription secret");
}

@test:Config {
    dependsOn: [testPublicationAndDelivery]
}
function testUnsubscription() returns error? {
    string formPayload = string `hub.mode=unsubscribe&hub.topic=${topicUrl}&hub.callback=${TEST_CALLBACK}`;
    http:Response response = check hubHttpClient->post("", formPayload, mediaType = "application/x-www-form-urlencoded");
    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Unsubscription request should be accepted");

    runtime:sleep(2);
    string key = subscriptionKey(topicUrl, TEST_CALLBACK);
    test:assertFalse(verifiedSubscriptions.hasKey(key), msg = "Subscription should be removed from in-memory tracking");
}

@test:Config {
    dependsOn: [testUnsubscription]
}
function testTopicDeregistration() returns error? {
    websubhub:TopicDeregistrationSuccess result = check testPublisherClient->deregisterTopic(topicUrl);
    test:assertEquals(result.statusCode, http:STATUS_OK, msg = "Topic deregistration should succeed");
    test:assertFalse(isTopicRegistered(topicUrl), msg = "Topic should no longer be registered");
}
