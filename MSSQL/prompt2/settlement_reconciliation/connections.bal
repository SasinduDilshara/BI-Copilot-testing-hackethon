import ballerinax/mssql;
import ballerinax/mssql.driver as _;
import ballerina/http;

final mssql:Client settlementClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbName
);

final http:Client processorClient = check new (processorApiUrl, timeout = 15);
