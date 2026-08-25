import ballerina/cache;
import ballerina/http;
import ballerina/log;

listener http:Listener gatewayListener = new (9090);

service /gateway on gatewayListener {

    resource function post validate(@http:Payload TokenValidationRequest tokenValidationRequest)
            returns TokenValidationResult|http:Unauthorized {

        string token = tokenValidationRequest.token;

        boolean isCached = tokenValidationCache.hasKey(token);
        if isCached {
            any|cache:Error cachedValue = tokenValidationCache.get(token);
            if cachedValue is TokenValidationResult {
                cachedValue.cacheHit = true;
                return cachedValue;
            }
        }

        if upstreamValidTokens.hasKey(token) {
            UpstreamTokenDetails upstreamTokenDetails = upstreamValidTokens.get(token);
            TokenValidationResult validationResult = {
                valid: true,
                clientId: upstreamTokenDetails.clientId,
                allowedScopes: upstreamTokenDetails.allowedScopes,
                expiresInSeconds: upstreamTokenDetails.expiresInSeconds,
                cacheHit: false
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
}
