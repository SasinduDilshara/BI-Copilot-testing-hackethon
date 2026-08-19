
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;
import ballerina/http;

final postgresql:Client ledgerClient = check new (
    host = dbHost, port = dbPort, username = dbUser, password = dbPassword, database = dbName
);

final http:Client reconciliationClient = check new (reconciliationApiUrl, timeout = 10);