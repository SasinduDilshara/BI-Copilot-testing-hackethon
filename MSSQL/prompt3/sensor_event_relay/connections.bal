
import ballerinax/mssql;
import ballerinax/mssql.driver as _;
import ballerinax/mssql.cdc.driver as _;
import ballerina/http;

final http:Client analyticsClient = check new (analyticsApiUrl, timeout = 10);

# Single CDC listener that captures sensor_events changes from all three plant
# databases on the named instance. Each database gets its own task (tasksMax: 3,
# one per database) so that a burst of changes on one plant cannot starve the
# others out of processing time. The streaming query mode is set to DIRECT so
# that the table is queried directly instead of relying on the CDC change-tracking
# function, which the nightly retention job's TRUNCATE would otherwise silently break.
listener mssql:CdcListener plantSensorEventsListener = new ({
    database: {
        hostname: dbHost,
        databaseInstance: dbInstance,
        databaseNames: ["plant_east_db", "plant_west_db", "plant_north_db"],
        includedTables: ["dbo.sensor_events"],
        username: dbUser,
        password: dbPassword,
        tasksMax: 3,
        streamingConfig: {
            dataQueryMode: mssql:DIRECT
        }
    }
});