
import ballerinax/oracledb;
import ballerinax/oracledb.driver as _;
import ballerina/http;

final oracledb:Client positionsClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbService
);

final http:Client riskEngineClient = check new (riskEngineUrl, timeout = 10);