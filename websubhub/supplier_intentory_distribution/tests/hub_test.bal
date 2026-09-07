import ballerina/http;
import ballerina/lang.runtime;
import ballerina/test;
import ballerina/websubhub;

const string TEST_CALLBACK = "http://localhost:9210/callback";

final http:Client hubHttpClient = check new (string `http://localhost:${hubPort.toString()}/websubhub`);
final websubhub:PublisherClient testPublisherClient = check new (hubUrl);

// In-memory store of content distribution notifications received by the mock subscriber callback.
map<json[]> receivedNotifications = {};

@test:BeforeSuite
function beforeSuite() returns error? {
    // Allow time for the hub and publisher listeners declared in main.bal to fully start.
    runtime:sleep(3);
}

// Plain HTTP mock callback service acting as a WebSub subscriber. This allows testing
// websubhub content distribution without importing ballerina/websub.
service /callback on new http:Listener(9210) {

    resource function post .(@http:Payload json content) returns http:Ok {
        json[] existing = receivedNotifications[TEST_CALLBACK] ?: [];
        existing.push(content);
        receivedNotifications[TEST_CALLBACK] = existing;
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
function testSubscriptionVerification() returns error? {
    string formPayload = string `hub.mode=subscribe&hub.topic=${topicUrl}&hub.callback=${TEST_CALLBACK}&hub.lease_seconds=${leaseSeconds.toString()}`;
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
