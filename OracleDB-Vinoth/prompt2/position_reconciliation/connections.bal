
import ballerinax/oracledb;
import ballerinax/oracledb.driver as _;
import ballerinax/oracledb.cdc.driver as _;
import ballerinax/cdc;
import ballerina/http;

final oracledb:Client positionsClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbService
);

final http:Client riskEngineClient = check new (riskEngineUrl, timeout = 10);

// Connects against the CDB root (TRADECDB) with the pluggable database set to TRADEPDB.
// Both RAC nodes are supplied so LogMiner can continue mining after a failover.
// LogMiner buffering happens on the database side (LOGMINER_UNBUFFERED) instead of within
// the connector. Only changes made by the TRADE_ENGINE_SVC application account are captured,
// so manual back-office corrections made by other DB accounts are ignored.
listener oracledb:CdcListener positionsCdcListener = new (
    database = {
        username: cdcUsername,
        password: cdcPassword,
        databaseName: cdbName,
        pdbName: pdbName,
        racNodes: racNodes,
        adapterMode: oracledb:LOGMINER_UNBUFFERED,
        includedTables: "POSITIONS",
        logMinerConfig: {
            includedUsernames: "TRADE_ENGINE_SVC"
        }
    },
    options = {
        snapshotMode: cdc:NO_DATA
    }
);