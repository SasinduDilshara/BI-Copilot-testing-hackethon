
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// Used by the nightly_reconciliation automation
final mysql:Client meterReadingsClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbName,
    options = {...buildDbOptions()},
    connectionPool = {maxOpenConnections: 10, minIdleConnections: 2, maxConnectionLifeTime: 1800}
);

// Used by the hourly_anomaly_scan automation
final mysql:Client anomalyScanClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbName,
    options = {...buildDbOptions()},
    connectionPool = {maxOpenConnections: 5, minIdleConnections: 1, maxConnectionLifeTime: 1800}
);

// Used by the ad-hoc audit automation
final mysql:Client adhocAuditClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbName,
    options = {...buildDbOptions()},
    connectionPool = {maxOpenConnections: 3, minIdleConnections: 1, maxConnectionLifeTime: 1800}
);