import ballerina/cache;
import ballerina/http;

service /ratelimit on new http:Listener(servicePort) {

    resource function post 'check(@http:Payload RateLimitRequest rateLimitRequest) returns http:Ok|http:TooManyRequests {
        string clientId = rateLimitRequest.clientId;
        string endpoint = rateLimitRequest.endpoint;
        ClientTier clientTier = rateLimitRequest.clientTier;
        string cacheKey = clientId + ":" + endpoint;

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
