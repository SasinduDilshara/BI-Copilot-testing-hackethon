
import ballerinax/oracledb;
import ballerinax/oracledb.driver as _;
import ballerina/http;

final oracledb:Client claimsClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbService
);

final http:Client clearinghouseClient = check new (clearinghouseApiUrl, timeout = 20);