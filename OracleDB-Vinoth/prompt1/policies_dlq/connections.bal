import ballerinax/oracledb;
import ballerinax/oracledb.driver as _;

final oracledb:Client policyDbClient = check new (
    host = dbHost,
    port = dbPort,
    user = dbUser,
    password = dbPassword,
    database = dbDatabase,
    options = {autoCommit: false}
);
