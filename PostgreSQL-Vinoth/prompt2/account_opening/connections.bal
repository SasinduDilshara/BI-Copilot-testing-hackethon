
import ballerina/http;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;

final http:Client identityClient = check new (identityApiUrl,
    timeout = 12,
    retryConfig = {count: 2, interval: 3}
);

final postgresql:Client dbClient = check new (
    host = dbHost,
    port = dbPort,
    username = dbUsername,
    password = dbPassword,
    database = dbName,
    options = {
        ssl: {
            mode: postgresql:REQUIRE
        }
    },
    connectionPool = {
        maxOpenConnections: 12,
        minIdleConnections: 3,
        maxConnectionLifeTime: 1800
    }
);