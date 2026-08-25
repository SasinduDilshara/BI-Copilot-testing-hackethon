function getLimitForTier(ClientTier clientTier) returns int {
    if clientTier == "premium" {
        return PREMIUM_TIER_LIMIT;
    }
    return FREE_TIER_LIMIT;
}

function recordViolationAndCheckBlock(string clientId) returns boolean {
    boolean violationKeyExists = violationsCache.hasKey(clientId);
    int violationCount;
    if !violationKeyExists {
        violationCount = 1;
    } else {
        any|error cachedViolationCount = violationsCache.get(clientId);
        int existingViolationCount = 0;
        if cachedViolationCount is int {
            existingViolationCount = cachedViolationCount;
        }
        violationCount = existingViolationCount + 1;
    }
    error? violationCacheError = violationsCache.put(clientId, violationCount, <decimal>VIOLATION_WINDOW_SECONDS);
    if violationCacheError is error {
        return false;
    }

    if violationCount >= VIOLATION_THRESHOLD {
        error? blockCacheError = blockedClientsCache.put(clientId, BLOCK_DURATION_SECONDS, <decimal>BLOCK_DURATION_SECONDS);
        if blockCacheError is error {
            return false;
        }
        return true;
    }
    return false;
}
