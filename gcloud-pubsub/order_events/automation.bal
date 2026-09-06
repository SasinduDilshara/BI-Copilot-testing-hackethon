import ballerinax/gcloud.pubsub;

// Consumes order events from the configured subscription, processing each
// event before acknowledging it. Acknowledgement only happens after
// successful processing; a transient processing failure triggers a negative
// acknowledgement so the broker redelivers the message.
service on orderEventListener {

    remote function onMessage(pubsub:Message message, pubsub:Caller caller) returns error? {
        check handleIncomingOrderEvent(message, caller);
    }
}
