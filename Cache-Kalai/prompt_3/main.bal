import ballerina/cache;
import ballerina/http;

service /ratelimit on new http:Listener(servicePort) {

    resource function post 'check(@http:Payload RateLimitRequest rateLimitRequest) returns http:Ok|http:TooManyRequests {
        string clientId = rateLimitRequest.clientId;
        string endpoint = rateLimitRequest.endpoint;
        ClientTier clientTier = rateLimitRequest.clientTier;
        string cacheKey = clientId + ":" + endpoint;

        boolean isBlocked = blockedClientsCache.hasKey(clientId);
        if isBlocked {
            any|error cachedBlockExpiry = blockedClientsCache.get(clientId);
            int blockExpiresInSeconds = BLOCK_DURATION_SECONDS;
            if cachedBlockExpiry is int {
                blockExpiresInSeconds = cachedBlockExpiry;
            }
            return buildBlockedResponse(blockExpiresInSeconds);
        }

        int limitPerMinute = getLimitForTier(clientTier);
        int currentCount;

        boolean keyExists = rateLimitCache.hasKey(cacheKey);
        if !keyExists {
            currentCount = 1;
            error? cacheError = rateLimitCache.put(cacheKey, currentCount, <decimal>RATE_LIMIT_WINDOW_SECONDS);
            if cacheError is error {
                return buildTooManyRequestsResponse(currentCount, limitPerMinute);
            }
        } else {
            any|cache:Error cachedValue = rateLimitCache.get(cacheKey);
            int existingCount = 0;
            if cachedValue is int {
                existingCount = cachedValue;
            }
            currentCount = existingCount + 1;
            error? cacheError = rateLimitCache.put(cacheKey, currentCount, <decimal>RATE_LIMIT_WINDOW_SECONDS);
            if cacheError is error {
                return buildTooManyRequestsResponse(currentCount, limitPerMinute);
            }
        }

        if currentCount > limitPerMinute {
            boolean nowBlocked = recordViolationAndCheckBlock(clientId);
            if nowBlocked {
                error? invalidateError = rateLimitCache.invalidate(cacheKey);
                if invalidateError is error {
                    return buildTooManyRequestsResponse(currentCount, limitPerMinute);
                }
                return buildBlockedResponse(BLOCK_DURATION_SECONDS);
            }
            return buildTooManyRequestsResponse(currentCount, limitPerMinute);
        }

        RateLimitResponse rateLimitResponse = {
            allowed: true,
            currentCount: currentCount,
            limitPerMinute: limitPerMinute,
            retryAfterSeconds: 0
        };
        http:Ok okResponse = {body: rateLimitResponse};
        return okResponse;
    }
}

function buildTooManyRequestsResponse(int currentCount, int limitPerMinute) returns http:TooManyRequests {
    RateLimitResponse rateLimitResponse = {
        allowed: false,
        currentCount: currentCount,
        limitPerMinute: limitPerMinute,
        retryAfterSeconds: RATE_LIMIT_WINDOW_SECONDS
    };
    http:TooManyRequests tooManyRequestsResponse = {body: rateLimitResponse};
    return tooManyRequestsResponse;
}

function buildBlockedResponse(int blockExpiresInSeconds) returns http:TooManyRequests {
    RateLimitResponse rateLimitResponse = {
        allowed: false,
        currentCount: 0,
        limitPerMinute: 0,
        retryAfterSeconds: blockExpiresInSeconds,
        blocked: true,
        blockExpiresInSeconds: blockExpiresInSeconds
    };
    http:TooManyRequests tooManyRequestsResponse = {body: rateLimitResponse};
    return tooManyRequestsResponse;
}
