import ballerina/cache;

// In-memory cache for storing validated token results, keyed by the token string.
final cache:Cache tokenValidationCache = new (
    capacity = 500,
    evictionFactor = 0.25,
    defaultMaxAge = -1,
    cleanupInterval = 30
);

// Hardcoded set of valid tokens simulating an upstream authorization server.
final map<UpstreamTokenDetails> upstreamValidTokens = {
    "token-alpha-001": {
        clientId: "client-alpha",
        allowedScopes: ["read", "write"],
        expiresInSeconds: 3600
    },
    "token-beta-002": {
        clientId: "client-beta",
        allowedScopes: ["read"],
        expiresInSeconds: 1800
    },
    "token-gamma-003": {
        clientId: "client-gamma",
        allowedScopes: ["read", "write", "admin"],
        expiresInSeconds: 7200
    },
    "token-delta-004": {
        clientId: "client-delta",
        allowedScopes: ["read", "write"],
        expiresInSeconds: 900
    },
    "token-epsilon-005": {
        clientId: "client-epsilon",
        allowedScopes: ["read"],
        expiresInSeconds: 300
    }
};
