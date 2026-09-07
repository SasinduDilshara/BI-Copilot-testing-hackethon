import ballerina/http;
import ballerina/log;
import ballerina/websubhub;

// WebSub hub service handling topic registration/deregistration, subscription/unsubscription
// with automatic intent verification, and content distribution notifications.
@websubhub:ServiceConfig {
    leaseSeconds: leaseSeconds,
    autoVerifySubscriptionIntent: true
}
service /websubhub on new websubhub:Listener(hubPort) {

    remote function onRegisterTopic(websubhub:TopicRegistration msg, http:Headers headers)
            returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        string topic = msg.topic;
        if isTopicRegistered(topic) {
            return error websubhub:TopicRegistrationError("topic already registered", statusCode = http:STATUS_CONFLICT);
        }
        addRegisteredTopic(topic);
        log:printInfo("topic registered", topic = topic);
        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }

    remote function onDeregisterTopic(websubhub:TopicDeregistration msg, http:Headers headers)
            returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {
        string topic = msg.topic;
        if !isTopicRegistered(topic) {
            return error websubhub:TopicDeregistrationError("topic not registered", statusCode = http:STATUS_NOT_FOUND);
        }
        removeRegisteredTopic(topic);
        log:printInfo("topic deregistered", topic = topic);
        return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
    }

    remote function onUpdateMessage(websubhub:UpdateMessage msg, http:Headers headers)
            returns websubhub:Acknowledgement|websubhub:UpdateMessageError {
        string topic = msg.hubTopic;
        if !isTopicRegistered(topic) {
            return error websubhub:UpdateMessageError("topic not registered", statusCode = http:STATUS_NOT_FOUND);
        }
        VerifiedSubscriber[] subscribers = getVerifiedSubscriptionsForTopic(topic);
        foreach VerifiedSubscriber subscriber in subscribers {
            websubhub:HubClient|error hubClientResult = new (subscriberToSubscription(subscriber));
            if hubClientResult is error {
                log:printError("error creating hub client for subscriber", hubClientResult, callback = subscriber.hubCallback);
                continue;
            }
            websubhub:ContentDistributionSuccess|websubhub:SubscriptionDeletedError|error distributionResult =
                hubClientResult->notifyContentDistribution({content: msg.content, contentType: msg.contentType});
            if distributionResult is error {
                log:printError("error delivering content to subscriber", distributionResult, callback = subscriber.hubCallback);
            }
        }
        return websubhub:ACKNOWLEDGEMENT;
    }

    remote function onSubscriptionValidation(websubhub:Subscription msg) returns websubhub:SubscriptionDeniedError? {
        if !isTopicRegistered(msg.hubTopic) {
            return error websubhub:SubscriptionDeniedError("topic not registered", statusCode = http:STATUS_NOT_FOUND);
        }
        return ();
    }

    remote function onSubscription(websubhub:Subscription msg, http:Headers headers, websubhub:Controller hubController)
            returns websubhub:SubscriptionAccepted|websubhub:InternalSubscriptionError {
        websubhub:Error? verifiedResult = hubController.markAsVerified(msg);
        if verifiedResult is websubhub:Error {
            return error websubhub:InternalSubscriptionError("error marking subscription as verified", statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
        return websubhub:SUBSCRIPTION_ACCEPTED;
    }

    remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription msg) {
        addVerifiedSubscription(msg);
        log:printInfo("subscription verified", topic = msg.hubTopic, callback = msg.hubCallback);
    }

    remote function onUnsubscriptionValidation(websubhub:Unsubscription msg) returns websubhub:UnsubscriptionDeniedError? {
        string key = subscriptionKey(msg.hubTopic, msg.hubCallback);
        if !verifiedSubscriptions.hasKey(key) {
            return error websubhub:UnsubscriptionDeniedError("subscription not found", statusCode = http:STATUS_NOT_FOUND);
        }
        return ();
    }

    remote function onUnsubscription(websubhub:Unsubscription msg, http:Headers headers, websubhub:Controller hubController)
            returns websubhub:UnsubscriptionAccepted|websubhub:InternalUnsubscriptionError {
        websubhub:Error? verifiedResult = hubController.markAsVerified(msg);
        if verifiedResult is websubhub:Error {
            return error websubhub:InternalUnsubscriptionError("error marking unsubscription as verified", statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
        return websubhub:UNSUBSCRIPTION_ACCEPTED;
    }

    remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription msg) {
        removeVerifiedSubscription(msg);
        log:printInfo("subscription removed", topic = msg.hubTopic, callback = msg.hubCallback);
    }
}

// Publisher-side HTTP endpoint that accepts supplier inventory stock updates and
// publishes them to the WebSub hub topic.
service /inventory on new http:Listener(publisherPort) {

    resource function post updates(@http:Payload StockUpdate stockUpdate) returns http:Ok|http:InternalServerError {
        json payload = stockUpdate.toJson();
        websubhub:Acknowledgement|websubhub:UpdateMessageError publishResult =
            publisherClient->publishUpdate(topicUrl, payload);
        if publishResult is websubhub:UpdateMessageError {
            log:printError("error publishing stock update", publishResult, eventId = stockUpdate.eventId);
            return <http:InternalServerError>{body: {message: "failed to publish stock update"}};
        }
        return <http:Ok>{body: {message: "stock update published", eventId: stockUpdate.eventId}};
    }
}
