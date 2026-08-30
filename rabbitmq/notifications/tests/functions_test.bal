import ballerina/test;
import ballerinax/rabbitmq;

function sampleNotificationRequest(NotificationUrgency urgency, NotificationChannel[] channels) returns NotificationRequest => {
    tenantId: "tenant-a",
    notificationId: "NOTIF-RESOLVE-1",
    recipients: ["someone@example.com"],
    subject: "Subject",
    body: "Body",
    channels,
    urgency
};

@test:Config {}
function testResolveDestinationsRoutesUrgentToUrgentOnly() {
    NotificationRequest notificationRequest = sampleNotificationRequest(URGENCY_URGENT, [CHANNEL_EMAIL, CHANNEL_PUSH]);
    NotificationChannel[] destinations = resolveDestinations(notificationRequest);
    test:assertEquals(destinations, [CHANNEL_URGENT],
            msg = "An urgent notification should be routed only to the urgent destination, bypassing its selected channels");
}

@test:Config {}
function testResolveDestinationsRoutesNonUrgentToSelectedChannels() {
    NotificationRequest notificationRequest = sampleNotificationRequest(URGENCY_HIGH, [CHANNEL_EMAIL, CHANNEL_PUSH]);
    NotificationChannel[] destinations = resolveDestinations(notificationRequest);
    test:assertEquals(destinations, [CHANNEL_EMAIL, CHANNEL_PUSH],
            msg = "A non-urgent notification should be routed to its selected channels");
}

@test:Config {}
function testResolveDestinationsRoutesSingleChannel() {
    NotificationRequest notificationRequest = sampleNotificationRequest(URGENCY_LOW, [CHANNEL_EMAIL]);
    NotificationChannel[] destinations = resolveDestinations(notificationRequest);
    test:assertEquals(destinations, [CHANNEL_EMAIL],
            msg = "A notification selecting only email should be routed only to email");
}

@test:Config {}
function testExtractNotificationHeadersSucceeds() returns error? {
    rabbitmq:BasicProperties properties = {
        correlationId: "NOTIF-1",
        headers: {
            "x-tenant-id": "tenant-a",
            "x-notification-id": "NOTIF-1"
        }
    };
    [string, string] headerResult = check extractNotificationHeaders(properties);
    test:assertEquals(headerResult[0], "tenant-a", msg = "tenantId should be extracted from headers");
    test:assertEquals(headerResult[1], "NOTIF-1", msg = "notificationId should be extracted from headers");
}

@test:Config {}
function testExtractNotificationHeadersFailsWhenPropertiesAbsent() {
    [string, string]|error headerResult = extractNotificationHeaders(());
    test:assertTrue(headerResult is error, msg = "Extraction should fail when properties are absent");
}

@test:Config {}
function testExtractNotificationHeadersFailsWhenHeadersAbsent() {
    rabbitmq:BasicProperties properties = {correlationId: "NOTIF-2"};
    [string, string]|error headerResult = extractNotificationHeaders(properties);
    test:assertTrue(headerResult is error, msg = "Extraction should fail when headers are absent");
}

@test:Config {}
function testExtractNotificationHeadersFailsWhenTenantIdMissing() {
    rabbitmq:BasicProperties properties = {
        correlationId: "NOTIF-3",
        headers: {"x-notification-id": "NOTIF-3"}
    };
    [string, string]|error headerResult = extractNotificationHeaders(properties);
    test:assertTrue(headerResult is error, msg = "Extraction should fail when tenantId header is missing");
}

@test:Config {}
function testExtractNotificationHeadersFailsWhenNotificationIdMissing() {
    rabbitmq:BasicProperties properties = {
        correlationId: "NOTIF-4",
        headers: {"x-tenant-id": "tenant-a"}
    };
    [string, string]|error headerResult = extractNotificationHeaders(properties);
    test:assertTrue(headerResult is error, msg = "Extraction should fail when notificationId header is missing");
}
