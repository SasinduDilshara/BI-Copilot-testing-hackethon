import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;

final postgresql:Client dbClient = check new (
    host = dbHost,
    username = dbUsername,
    database = dbName,
    port = dbPort,
    options = {
        ssl: {
            mode: postgresql:VERIFY_FULL,
            rootcert: dbRootCertPath,
            key: {
                certFile: dbClientCertPath,
                keyFile: dbClientKeyPath
            }
        }
    },
    connectionPool = {
        maxOpenConnections: dbMaxOpenConnections,
        minIdleConnections: dbMinIdleConnections,
        maxConnectionLifeTime: dbMaxConnectionLifeTime
    }
);
