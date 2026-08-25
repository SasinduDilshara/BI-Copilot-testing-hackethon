import ballerina/cache;

final cache:Cache rateLimitCache = new (
    capacity = 10000,
    defaultMaxAge = 60,
    cleanupInterval = 10
);
