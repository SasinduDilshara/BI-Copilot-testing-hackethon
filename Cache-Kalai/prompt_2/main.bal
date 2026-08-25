import ballerina/cache;
import ballerina/http;
import ballerina/log;
import ballerina/time;

listener http:Listener gatewayListener = new (9090);

service /gateway on gatewayListener {

    resource function post validate(@http:Payload TokenValidationRequest tokenValidationRequest)
            returns TokenValidationResult|http:Unauthorized {

        string token = tokenValidationRequest.token;

        boolean isCached = tokenValidationCache.hasKey(token);
        if isCached {
            any|cache:Error cachedValue = tokenValidationCache.get(token);
            if cachedValue is TokenValidationResult {
                int currentEpochSeconds = time:utcNow()[0];
                int elapsedSeconds = currentEpochSeconds - cachedValue.cachedAt;
                if elapsedSeconds >= cachedValue.expiresInSeconds {
                    error? invalidateResult = tokenValidationCache.invalidate(token);
                    if invalidateResult is error {
                        log:printError("Failed to invalidate expired token from cache", invalidateResult);
                    }
                    ValidationErrorDetail expiredTokenError = {
                        message: "Token has expired",
                        token: token
                    };
                    return {
                        body: expiredTokenError
                    };
                }
                cachedValue.cacheHit = true;
                return cachedValue;
            }
        }

        if upstreamValidTokens.hasKey(token) {
            UpstreamTokenDetails upstreamTokenDetails = upstreamValidTokens.get(token);
            int currentEpochSeconds = time:utcNow()[0];
            TokenValidationResult validationResult = {
                valid: true,
                clientId: upstreamTokenDetails.clientId,
                allowedScopes: upstreamTokenDetails.allowedScopes,
                expiresInSeconds: upstreamTokenDetails.expiresInSeconds,
                cacheHit: false,
                cachedAt: currentEpochSeconds
            };

            decimal tokenMaxAge = <decimal>upstreamTokenDetails.expiresInSeconds;
            error? putResult = tokenValidationCache.put(token, validationResult, maxAge = tokenMaxAge);
            if putResult is error {
                log:printError("Failed to cache token validation result", putResult);
            }

            return validationResult;
        }

        ValidationErrorDetail validationErrorDetail = {
            message: "Token is not recognized by the authorization server",
            token: token
        };
        return {
            body: validationErrorDetail
        };
    }

    resource function post revoke(@http:Payload TokenRevocationRequest tokenRevocationRequest)
            returns TokenRevocationResult {

        string token = tokenRevocationRequest.token;
        string reason = tokenRevocationRequest.reason;

        boolean isCached = tokenValidationCache.hasKey(token);
        if isCached {
            error? invalidateResult = tokenValidationCache.invalidate(token);
            if invalidateResult is error {
                log:printError("Failed to invalidate token from cache", invalidateResult);
            }
            return {
                revoked: true,
                reason: reason
            };
        }

        return {
            revoked: false,
            reason: "Token was not in the active cache — it may have already expired or was never validated through this gateway"
        };
    }
}
