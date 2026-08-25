# Represents the tier of a client.
public type ClientTier "free"|"premium";

# Represents the rate limit check request.
public type RateLimitRequest record {|
    string clientId;
    ClientTier clientTier;
    string endpoint;
|};

# Represents the rate limit check response.
public type RateLimitResponse record {|
    boolean allowed;
    int currentCount;
    int limitPerMinute;
    int retryAfterSeconds;
|};
