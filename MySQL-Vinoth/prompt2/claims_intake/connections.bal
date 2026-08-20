import ballerina/http;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

final http:Client adjudicationClient = check new (adjudicationApiUrl,
    timeout = 15,
    retryConfig = {count: 2, interval: 3}
);

final mysql:SecureSocket dbSecureSocket = {
    mode: mysql:SSL_REQUIRED
};

final mysql:Client claimsDbClient = check new (
    host = dbHost,
    port = dbPort,
    user = dbUsername,
    password = dbPassword,
    database = dbName,
    options = {
        ssl: dbSecureSocket
    },
    connectionPool = {
        maxOpenConnections: 20,
        minIdleConnections: 4,
        maxConnectionLifeTime: 3600
    }
);

final mysql:Client claimsReportingDbClient = check new (
    host = reportingDbHost,
    port = reportingDbPort,
    user = reportingDbUsername,
    password = reportingDbPassword,
    database = reportingDbName,
    options = {
        ssl: dbSecureSocket
    },
    connectionPool = {
        maxOpenConnections: 5
    }
);
