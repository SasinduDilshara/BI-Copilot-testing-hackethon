import ballerina/cache;

final cache:Cache rateLimitCache = new (
    capacity = 10000,
    defaultMaxAge = 60,
    cleanupInterval = 10
);

final cache:Cache blockedClientsCache = new (
    capacity = 1000,
    defaultMaxAge = 300,
    cleanupInterval = 10
);

final cache:Cache violationsCache = new (
    capacity = 10000,
    defaultMaxAge = 600,
    cleanupInterval = 10
);
