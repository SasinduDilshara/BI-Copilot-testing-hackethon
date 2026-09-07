import ballerina/websubhub;

function subscriberToSubscription(VerifiedSubscriber subscriber) returns websubhub:Subscription => {
    hub: hubUrl,
    hubMode: "subscribe",
    hubCallback: subscriber.hubCallback,
    hubTopic: subscriber.hubTopic,
    hubLeaseSeconds: subscriber.hubLeaseSeconds,
    hubSecret: subscriber.hubSecret
};
