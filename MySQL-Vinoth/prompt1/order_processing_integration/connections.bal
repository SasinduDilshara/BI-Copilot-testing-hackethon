import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// Shared connection pool configuration reused across the primary and replica
// clients so connections are pooled and reused rather than opened per request.
final sql:ConnectionPool dbConnectionPool = {
    maxOpenConnections: dbMaxOpenConnections,
    minIdleConnections: dbMinIdleConnections,
    maxConnectionLifeTime: dbMaxConnectionLifeTimeSeconds
};

// Certificate-based TLS with hostname (identity) verification enabled.
final mysql:Options dbSecureOptions = {
    ssl: {
        mode: mysql:SSL_VERIFY_IDENTITY,
        key: {
            path: dbKeyStorePath,
            password: dbKeyStorePassword
        },
        cert: {
            path: dbTrustStorePath,
            password: dbTrustStorePassword
        }
    },
    connectTimeout: 10
};

// Primary database client, created once at module level and reused for the
// lifetime of the service.
final mysql:Client primaryDbClient = check new (
    host = primaryDbHost,
    user = dbUsername,
    password = dbPassword,
    database = dbName,
    port = primaryDbPort,
    options = dbSecureOptions,
    connectionPool = dbConnectionPool
);

// Read-only replica clients used when the primary database is unavailable.
final mysql:Client replicaOneDbClient = check new (
    host = replicaOneDbHost,
    user = dbUsername,
    password = dbPassword,
    database = dbName,
    port = replicaOneDbPort,
    options = dbSecureOptions,
    connectionPool = dbConnectionPool
);

final mysql:Client replicaTwoDbClient = check new (
    host = replicaTwoDbHost,
    user = dbUsername,
    password = dbPassword,
    database = dbName,
    port = replicaTwoDbPort,
    options = dbSecureOptions,
    connectionPool = dbConnectionPool
);

// Ordered list of clients used for the primary-then-replica failover strategy.
final mysql:Client[] orderedDbClients = [primaryDbClient, replicaOneDbClient, replicaTwoDbClient];
