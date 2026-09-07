import ballerina/crypto;
import ballerina/http;
import ballerina/lang.regexp;
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

// Extracts the host (without port) from a callback URL, e.g. "http://example.com:8080/cb" -> "example.com".
function extractCallbackHost(string callback) returns string? {
    regexp:RegExp hostPattern = re `^[a-zA-Z][a-zA-Z0-9+.-]*://([^/:]+)`;
    regexp:Groups? groups = hostPattern.findGroups(callback);
    if groups is regexp:Groups {
        regexp:Span? hostSpan = groups[1];
        if hostSpan is regexp:Span {
            return hostSpan.substring();
        }
    }
    return ();
}

function isCallbackHostAllowed(string callback) returns boolean {
    string? host = extractCallbackHost(callback);
    if host is () {
        return false;
    }
    return allowedCallbackHosts.indexOf(host) is int;
}

// Computes the WebSub content signature (sha256=<hex-hmac>) for the given content using the subscription secret.
function computeContentSignature(byte[] content, string secret) returns string|error {
    byte[] hmac = check crypto:hmacSha256(content, secret.toBytes());
    return string `sha256=${hmac.toBase16()}`;
}

// Validates an incoming subscription request against the configured topic, allowed callback hosts, and secret.
function validateSubscriptionRequest(string topic, string callback, string? hubSecret) returns websubhub:SubscriptionDeniedError? {
    if topic != topicUrl {
        return error websubhub:SubscriptionDeniedError("unknown topic", statusCode = http:STATUS_NOT_FOUND);
    }
    if !isCallbackHostAllowed(callback) {
        return error websubhub:SubscriptionDeniedError("callback host not allowed", statusCode = http:STATUS_FORBIDDEN);
    }
    if hubSecret is () || hubSecret != subscriptionSecret {
        return error websubhub:SubscriptionDeniedError("missing or incorrect subscription secret", statusCode = http:STATUS_UNAUTHORIZED);
    }
    return ();
}
