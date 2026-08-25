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
    boolean blocked = false;
    int blockExpiresInSeconds?;
|};

# Represents the current rate limit status for a client across all endpoints.
public type ClientRateLimitStatus record {|
    string clientId;
    boolean isBlocked;
    string[] activeEndpoints;
    map<int> counters;
|};

# Represents the result of resetting a client's rate limit data.
public type ClientResetResult record {|
    string clientId;
    boolean reset;
    int clearedEntryCount;
|};
