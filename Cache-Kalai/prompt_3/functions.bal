function getLimitForTier(ClientTier clientTier) returns int {
    if clientTier == "premium" {
        return PREMIUM_TIER_LIMIT;
    }
    return FREE_TIER_LIMIT;
}
