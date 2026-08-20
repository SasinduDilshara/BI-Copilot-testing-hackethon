
import ballerinax/mssql;
import ballerinax/mssql.driver as _;
import ballerina/http;

final mssql:Client eastPlantClient = check new (
    host = dbHost, instance = dbInstance, user = dbUser, password = dbPassword, database = "plant_east_db"
);

final mssql:Client westPlantClient = check new (
    host = dbHost, instance = dbInstance, user = dbUser, password = dbPassword, database = "plant_west_db"
);

final http:Client analyticsClient = check new (analyticsApiUrl, timeout = 10);