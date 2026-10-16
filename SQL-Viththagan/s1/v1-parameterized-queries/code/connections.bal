import ballerina/sql;
import ballerinax/h2.driver as _;
import ballerinax/java.jdbc;

configurable string databaseUrl = "jdbc:h2:mem:ordersdb";
configurable string databaseUser = "sa";
configurable string databasePassword = "";

final jdbc:Client dbClient = check new (url = databaseUrl, user = databaseUser, password = databasePassword);
