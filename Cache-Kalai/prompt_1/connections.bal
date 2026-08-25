import ballerina/cache;

// Module-level cache instance used to store product data.
final cache:Cache productCache = new (
    capacity = 100,
    evictionFactor = 0.2,
    defaultMaxAge = 300,
    cleanupInterval = 60
);
