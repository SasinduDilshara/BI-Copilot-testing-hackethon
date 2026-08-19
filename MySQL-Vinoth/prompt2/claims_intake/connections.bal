import ballerina/http;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

final http:Client adjudicationClient = check new (adjudicationApiUrl,
    timeout = 15,
    retryConfig = {count: 2, interval: 3}
);

final mysql:Client claimsDbClient = check new (
    host = dbHost,
    port = dbPort,
    user = dbUsername,
    password = dbPassword,
    database = dbName,
    options = {
        ssl: {
            mode: mysql:SSL_REQUIRED
        }
    },
    connectionPool = {
        maxOpenConnections: 20,
        minIdleConnections: 4,
        maxConnectionLifeTime: 3600
    }
);
