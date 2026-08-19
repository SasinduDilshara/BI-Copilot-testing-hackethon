import ballerina/lang.runtime;
import ballerina/log;
import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// Validated at module load time so the service fails fast with a clear,
// specific error during startup instead of crashing later with a raw MySQL
// driver error when the pool/clients are constructed.
final error? dbPoolConfigValidationResult = validatePoolConfig();

// Shared connection pool configuration reused across the primary and replica
// clients so connections are pooled and reused rather than opened per request.
// Since each client connects to a different host, each one gets its own
// dedicated pool sized per these settings, allowing concurrent requests to be
// served without exhausting connections.
final sql:ConnectionPool dbConnectionPool = buildValidatedConnectionPool();

// Builds the connection pool configuration, panicking with a clear,
// actionable message if the pool sizing configuration failed validation.
function buildValidatedConnectionPool() returns sql:ConnectionPool {
    error? validationResult = dbPoolConfigValidationResult;
    if validationResult is error {
        panic error(string `Database connection pool configuration is invalid: ${validationResult.message()}`);
    }
    return {
        maxOpenConnections: dbMaxOpenConnections,
        minIdleConnections: dbMinIdleConnections,
        maxConnectionLifeTime: dbMaxConnectionLifeTimeSeconds,
        connectionTimeout: dbConnectionTimeoutSeconds
    };
}

// Certificate-based TLS with hostname (identity) verification enabled.
// This must remain SSL_VERIFY_IDENTITY (full certificate chain validation
// plus hostname verification) and must never be weakened to a lesser mode
// such as SSL_VERIFY_CA (no hostname check), SSL_REQUIRED, or SSL_PREFERRED
// (both of which allow unverified/unencrypted fallback).
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

// Ensures all database connection pools are released gracefully when the
// service is shut down (e.g. on SIGTERM during a Kubernetes rollout), after
// the HTTP listener has stopped accepting new requests and in-flight
// requests have been drained.
function init() {
    runtime:onGracefulStop(function() returns error? {
        // Only a static, generic message is logged here. The underlying
        // driver error is intentionally not logged since it may embed
        // connection details such as hostnames, ports, or file paths.
        error? primaryCloseResult = primaryDbClient.close();
        if primaryCloseResult is error {
            log:printError("Failed to close primary database client cleanly during shutdown");
        }

        error? replicaOneCloseResult = replicaOneDbClient.close();
        if replicaOneCloseResult is error {
            log:printError("Failed to close replica one database client cleanly during shutdown");
        }

        error? replicaTwoCloseResult = replicaTwoDbClient.close();
        if replicaTwoCloseResult is error {
            log:printError("Failed to close replica two database client cleanly during shutdown");
        }
    });
}
