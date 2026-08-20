import ballerinax/mssql;
import ballerinax/mssql.driver as _;

// Shared secure-socket configuration: encryption is enforced and the server
// certificate is validated against the configured truststore instead of
// accepting the driver defaults (trustServerCertificate is left false).
final mssql:Options mssqlSecureOptions = {
    secureSocket: {
        encrypt: true,
        trustServerCertificate: false,
        cert: {
            path: sqlServerTrustStorePath,
            password: sqlServerTrustStorePassword
        }
    },
    // Both clients participate in the same distributed (XA) transaction, so
    // each connection must be backed by an XA datasource.
    useXADatasource: true
};

// Client for the work_order_completions table. No fixed port is supplied -
// the named instance is resolved dynamically via SQL Browser.
final mssql:Client workOrdersDbClient = check new (
    host = sqlServerHost,
    user = sqlServerUser,
    password = sqlServerPassword,
    database = workOrdersDatabase,
    instance = sqlServerInstance,
    options = mssqlSecureOptions
);

// Client for the parts_inventory database on the same named instance.
final mssql:Client partsInventoryDbClient = check new (
    host = sqlServerHost,
    user = sqlServerUser,
    password = sqlServerPassword,
    database = partsInventoryDatabase,
    instance = sqlServerInstance,
    options = mssqlSecureOptions
);
