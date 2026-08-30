import ballerina/time;

# In-memory delivery tracker keyed by "notificationId::channel", used to suppress duplicate
# processing when a message is redelivered (e.g. after a nack/requeue or a consumer crash
# before it acknowledged). Also backs the GET /notifications/{notificationId} status endpoint.
isolated map<ChannelDelivery> deliveryStore = {};

# Builds the composite key used to track a single (notificationId, channel) delivery.
#
# + notificationId - the notification the delivery belongs to
# + channel - the channel the delivery was made over
# + return - the composite tracking key
isolated function deliveryKey(string notificationId, NotificationChannel channel) returns string {
    return string `${notificationId}::${channel}`;
}

# Checks whether a (notificationId, channel) pair has already been recorded as delivered.
#
# + notificationId - the notification to check
# + channel - the channel to check
# + return - true if this pair has already been delivered
isolated function isAlreadyDelivered(string notificationId, NotificationChannel channel) returns boolean {
    lock {
        return deliveryStore.hasKey(deliveryKey(notificationId, channel));
    }
}

# Records that a (notificationId, channel) pair has completed delivery.
#
# + notificationId - the notification that was delivered
# + channel - the channel it was delivered over
isolated function recordDelivery(string notificationId, NotificationChannel channel) {
    ChannelDelivery channelDelivery = {channel, deliveredAt: time:utcToString(time:utcNow())};
    lock {
        deliveryStore[deliveryKey(notificationId, channel)] = channelDelivery.clone();
    }
}

# Looks up every channel delivery recorded so far for a notification.
#
# + notificationId - the notification to look up
# + return - the recorded deliveries, in no particular order; empty if none are recorded
isolated function getDeliveries(string notificationId) returns ChannelDelivery[] {
    string prefix = notificationId + "::";
    map<ChannelDelivery> deliverySnapshot;
    lock {
        deliverySnapshot = deliveryStore.clone();
    }
    ChannelDelivery[] deliveries = [];
    foreach string trackingKey in deliverySnapshot.keys() {
        if trackingKey.startsWith(prefix) {
            deliveries.push(deliverySnapshot.get(trackingKey));
        }
    }
    return deliveries;
}

# In-memory fixed-window rate limiter counters keyed by "tenantId::channel". Each entry tracks
# how many notifications the tenant has been allowed on that channel within the current window,
# and when the current window started.
isolated map<RateWindow> rateLimitStore = {};

# A single tenant+channel's current rate-limit window.
type RateWindow record {|
    decimal windowStart;
    int count;
|};

# Builds the composite key used to track a single tenant's rate limit on a channel.
#
# + tenantId - the tenant to track
# + channel - the channel to track
# + return - the composite tracking key
isolated function rateLimitKey(string tenantId, NotificationChannel channel) returns string {
    return string `${tenantId}::${channel}`;
}

# Checks whether a tenant is currently within its per-channel rate limit, consuming one unit of
# quota if so. Uses a simple fixed-window counter: once `rateLimitWindowSeconds` have elapsed
# since the window started, the counter resets.
#
# + tenantId - the tenant to check
# + channel - the channel to check
# + return - true if the tenant is within its limit (and the call has been counted against it),
# false if the tenant is over the limit for the current window
isolated function tryConsumeRateLimit(string tenantId, NotificationChannel channel) returns boolean {
    string trackingKey = rateLimitKey(tenantId, channel);
    decimal now = <decimal>time:utcNow()[0];
    lock {
        RateWindow? currentWindow = rateLimitStore[trackingKey];
        if currentWindow is () || (now - currentWindow.windowStart) >= rateLimitWindowSeconds {
            rateLimitStore[trackingKey] = {windowStart: now, count: 1};
            return true;
        }
        if currentWindow.count >= tenantRateLimitPerWindow {
            return false;
        }
        rateLimitStore[trackingKey] = {windowStart: currentWindow.windowStart, count: currentWindow.count + 1};
        return true;
    }
}
