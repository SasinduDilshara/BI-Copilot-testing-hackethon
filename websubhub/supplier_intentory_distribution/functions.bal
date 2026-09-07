import ballerina/websubhub;

// In-memory store of registered topics.
map<boolean> registeredTopics = {};

// In-memory store of verified subscriptions, keyed by "topic|callback".
map<VerifiedSubscriber> verifiedSubscriptions = {};

function subscriptionKey(string topic, string callback) returns string {
    return topic + "|" + callback;
}

function addRegisteredTopic(string topic) {
    registeredTopics[topic] = true;
}

function removeRegisteredTopic(string topic) {
    _ = registeredTopics.removeIfHasKey(topic);
}

function isTopicRegistered(string topic) returns boolean {
    return registeredTopics.hasKey(topic);
}

function addVerifiedSubscription(websubhub:VerifiedSubscription subscription) {
    string key = subscriptionKey(subscription.hubTopic, subscription.hubCallback);
    verifiedSubscriptions[key] = {
        hubTopic: subscription.hubTopic,
        hubCallback: subscription.hubCallback,
        hubLeaseSeconds: subscription.hubLeaseSeconds,
        hubSecret: subscription.hubSecret
    };
}

function removeVerifiedSubscription(websubhub:VerifiedUnsubscription unsubscription) {
    string key = subscriptionKey(unsubscription.hubTopic, unsubscription.hubCallback);
    _ = verifiedSubscriptions.removeIfHasKey(key);
}

function getVerifiedSubscriptionsForTopic(string topic) returns VerifiedSubscriber[] {
    return from VerifiedSubscriber subscriber in verifiedSubscriptions
        where subscriber.hubTopic == topic
        select subscriber;
}
