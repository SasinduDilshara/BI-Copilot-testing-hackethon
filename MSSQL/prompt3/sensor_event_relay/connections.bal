
import ballerinax/mssql;
import ballerinax/mssql.driver as _;
import ballerinax/mssql.cdc.driver as _;
import ballerina/http;

final http:Client analyticsClient = check new (analyticsApiUrl, timeout = 10);

# Single CDC listener that captures sensor_events changes from both plant databases
# on the named instance. Each database gets its own task (tasksMax: 2), and the
# streaming query mode is set to DIRECT so that the table is queried directly
# instead of relying on the CDC change-tracking function, which the nightly
# retention job's TRUNCATE would otherwise silently break.
listener mssql:CdcListener plantSensorEventsListener = new ({
    database: {
        hostname: dbHost,
        databaseInstance: dbInstance,
        databaseNames: ["plant_east_db", "plant_west_db"],
        includedTables: ["dbo.sensor_events"],
        username: dbUser,
        password: dbPassword,
        tasksMax: 2,
        streamingConfig: {
            dataQueryMode: mssql:DIRECT
        }
    }
});