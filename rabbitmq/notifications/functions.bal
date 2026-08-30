import ballerinax/rabbitmq;

# Extracts the tenantId and notificationId carried in a notification message's headers.
# Both are required for a message to be processed by a channel consumer: the tenantId drives
# rate limiting and the notificationId drives delivery-dedup tracking.
#
# + properties - the message's basic properties, if present
# + return - the (tenantId, notificationId) pair, or an error describing which header is missing
function extractNotificationHeaders(rabbitmq:BasicProperties? properties) returns [string, string]|error {
    if properties is () {
        return error("Notification message is missing properties");
    }
    map<anydata>? headers = properties?.headers;
    if headers is () {
        return error("Notification message is missing headers");
    }
    anydata tenantIdValue = headers[TENANT_ID_HEADER];
    anydata notificationIdValue = headers[NOTIFICATION_ID_HEADER];
    if tenantIdValue is string && notificationIdValue is string {
        return [tenantIdValue, notificationIdValue];
    }
    return error("Notification message is missing the tenantId/notificationId headers");
}

# Determines which destination(s) a notification request should be published to. Urgency picks
# the destination: an `urgent` request is routed only to the dedicated urgent destination,
# bypassing its normally selected channels entirely; any other urgency is routed to each of its
# selected channels.
#
# + notificationRequest - the notification dispatch request
# + return - the destinations to publish the notification to
function resolveDestinations(NotificationRequest notificationRequest) returns NotificationChannel[] {
    if notificationRequest.urgency == URGENCY_URGENT {
        return [CHANNEL_URGENT];
    }
    return notificationRequest.channels;
}
