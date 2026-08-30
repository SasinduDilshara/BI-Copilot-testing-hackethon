import ballerina/lang.value;
import ballerina/log;
import ballerinax/rabbitmq;

# Common handling shared by every destination consumer: validates the message's
# tenant/notification headers, skips reprocessing if this (notificationId, destination) pair
# was already delivered (dedup on redelivery), enforces the tenant's per-destination rate limit
# (requeueing rather than dropping when over limit), and finally records the delivery.
#
# + message - the delivered notification message
# + channel - the destination this consumer handles
# + caller - handle used to ack/nack the original delivery
# + return - () once the delivery has been handled (acked or nacked), or an error if the
# message could not be decoded/processed
function handleChannelDelivery(rabbitmq:AnydataMessage message, NotificationChannel channel,
        rabbitmq:Caller caller) returns error? {
    [string, string]|error headerResult = extractNotificationHeaders(message?.properties);
    if headerResult is error {
        log:printError(string `Dropping malformed notification message on ${channel}: ${headerResult.message()}`);
        check caller->basicNack(requeue = false);
        return;
    }
    string tenantId = headerResult[0];
    string notificationId = headerResult[1];

    if isAlreadyDelivered(notificationId, channel) {
        log:printInfo(string `Duplicate delivery suppressed for notification ${notificationId} on ${channel}`);
        check caller->basicAck();
        return;
    }

    boolean withinRateLimit = tryConsumeRateLimit(tenantId, channel);
    if !withinRateLimit {
        log:printWarn(string `Tenant ${tenantId} exceeded its ${channel} rate limit; requeueing notification ${notificationId}`);
        check caller->basicNack(requeue = true);
        return;
    }

    NotificationRequest notificationRequest = check value:ensureType(message.content);
    log:printInfo(string `Dispatching notification ${notificationRequest.notificationId} to tenant ${tenantId} over ${channel}`);

    recordDelivery(notificationId, channel);
    check caller->basicAck();
}

# Email consumer: consumes every notification routed to `notifications.email`.
@rabbitmq:ServiceConfig {
    queueName: NOTIFICATIONS_EMAIL_QUEUE,
    autoAck: false
}
service rabbitmq:Service on emailQueueListener {
    remote function onMessage(rabbitmq:AnydataMessage message, rabbitmq:Caller caller) returns error? {
        check handleChannelDelivery(message, CHANNEL_EMAIL, caller);
    }
}

# Push consumer: consumes every notification routed to `notifications.push`.
@rabbitmq:ServiceConfig {
    queueName: NOTIFICATIONS_PUSH_QUEUE,
    autoAck: false
}
service rabbitmq:Service on pushQueueListener {
    remote function onMessage(rabbitmq:AnydataMessage message, rabbitmq:Caller caller) returns error? {
        check handleChannelDelivery(message, CHANNEL_PUSH, caller);
    }
}

# Urgent consumer: consumes every notification routed to `notifications.urgent` (urgency ==
# urgent), instead of that notification's normally selected channels.
@rabbitmq:ServiceConfig {
    queueName: NOTIFICATIONS_URGENT_QUEUE,
    autoAck: false
}
service rabbitmq:Service on urgentQueueListener {
    remote function onMessage(rabbitmq:AnydataMessage message, rabbitmq:Caller caller) returns error? {
        check handleChannelDelivery(message, CHANNEL_URGENT, caller);
    }
}
