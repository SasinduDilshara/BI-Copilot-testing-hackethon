import ballerina/test;

@test:Config {}
function testIsAlreadyDeliveredFalseInitially() {
    boolean alreadyDelivered = isAlreadyDelivered("NOTIF-STATE-1", CHANNEL_EMAIL);
    test:assertFalse(alreadyDelivered, msg = "A notification/channel pair with no recorded delivery should not be marked delivered");
}

@test:Config {}
function testRecordDeliveryMarksAsDelivered() {
    recordDelivery("NOTIF-STATE-2", CHANNEL_URGENT);
    boolean alreadyDelivered = isAlreadyDelivered("NOTIF-STATE-2", CHANNEL_URGENT);
    test:assertTrue(alreadyDelivered, msg = "A recorded delivery should be reported as already delivered");
}

@test:Config {}
function testRecordDeliveryIsPerChannel() {
    recordDelivery("NOTIF-STATE-3", CHANNEL_EMAIL);
    boolean emailDelivered = isAlreadyDelivered("NOTIF-STATE-3", CHANNEL_EMAIL);
    boolean pushDelivered = isAlreadyDelivered("NOTIF-STATE-3", CHANNEL_PUSH);
    test:assertTrue(emailDelivered, msg = "Email delivery should be recorded");
    test:assertFalse(pushDelivered, msg = "Push delivery should be independent of email delivery for the same notification");
}

@test:Config {}
function testGetDeliveriesReturnsAllRecordedChannels() {
    recordDelivery("NOTIF-STATE-4", CHANNEL_EMAIL);
    recordDelivery("NOTIF-STATE-4", CHANNEL_URGENT);
    recordDelivery("NOTIF-STATE-4", CHANNEL_PUSH);

    ChannelDelivery[] deliveries = getDeliveries("NOTIF-STATE-4");
    test:assertEquals(deliveries.length(), 3, msg = "All three channel deliveries should be recorded for this notification");
}

@test:Config {}
function testGetDeliveriesReturnsEmptyForUnknownNotification() {
    ChannelDelivery[] deliveries = getDeliveries("NOTIF-STATE-DOES-NOT-EXIST");
    test:assertEquals(deliveries.length(), 0, msg = "An unknown notification should have no recorded deliveries");
}

@test:Config {}
function testGetDeliveriesDoesNotLeakOtherNotifications() {
    recordDelivery("NOTIF-STATE-5", CHANNEL_EMAIL);
    recordDelivery("NOTIF-STATE-5-EXTRA", CHANNEL_EMAIL);

    ChannelDelivery[] deliveries = getDeliveries("NOTIF-STATE-5");
    test:assertEquals(deliveries.length(), 1, msg = "Only deliveries for the exact notification ID should be returned");
}

@test:Config {}
function testTryConsumeRateLimitAllowsWithinLimit() {
    boolean firstAttempt = tryConsumeRateLimit("tenant-rate-1", CHANNEL_EMAIL);
    boolean secondAttempt = tryConsumeRateLimit("tenant-rate-1", CHANNEL_EMAIL);
    test:assertTrue(firstAttempt, msg = "First notification within the window should be allowed");
    test:assertTrue(secondAttempt, msg = "Second notification within the configured limit should be allowed");
}

@test:Config {}
function testTryConsumeRateLimitBlocksOverLimit() {
    string tenantId = "tenant-rate-2";
    foreach int i in 0 ..< tenantRateLimitPerWindow {
        boolean allowed = tryConsumeRateLimit(tenantId, CHANNEL_URGENT);
        test:assertTrue(allowed, msg = "Attempts up to the configured limit should be allowed");
    }
    boolean overLimitAttempt = tryConsumeRateLimit(tenantId, CHANNEL_URGENT);
    test:assertFalse(overLimitAttempt, msg = "An attempt beyond the configured limit within the same window should be blocked");
}

@test:Config {}
function testTryConsumeRateLimitIsPerChannel() {
    string tenantId = "tenant-rate-3";
    foreach int i in 0 ..< tenantRateLimitPerWindow {
        boolean allowed = tryConsumeRateLimit(tenantId, CHANNEL_PUSH);
        test:assertTrue(allowed, msg = "Attempts up to the configured limit on push should be allowed");
    }
    boolean pushOverLimit = tryConsumeRateLimit(tenantId, CHANNEL_PUSH);
    boolean emailWithinLimit = tryConsumeRateLimit(tenantId, CHANNEL_EMAIL);
    test:assertFalse(pushOverLimit, msg = "Push should be over its own limit");
    test:assertTrue(emailWithinLimit, msg = "Email should have its own independent rate limit budget");
}

@test:Config {}
function testTryConsumeRateLimitIsPerTenant() {
    foreach int i in 0 ..< tenantRateLimitPerWindow {
        boolean allowed = tryConsumeRateLimit("tenant-rate-4", CHANNEL_EMAIL);
        test:assertTrue(allowed, msg = "Attempts up to the configured limit should be allowed for tenant-rate-4");
    }
    boolean tenantAOverLimit = tryConsumeRateLimit("tenant-rate-4", CHANNEL_EMAIL);
    boolean otherTenantWithinLimit = tryConsumeRateLimit("tenant-rate-5", CHANNEL_EMAIL);
    test:assertFalse(tenantAOverLimit, msg = "tenant-rate-4 should be over its own limit");
    test:assertTrue(otherTenantWithinLimit, msg = "A different tenant should have an independent rate limit budget");
}
