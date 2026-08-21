
configurable string dbHost = ?;
configurable int dbPort = 1521;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbService = "TRADEPDB";

// CDC listener connects to the CDB root; the position data lives in the TRADEPDB pluggable database.
// Both RAC nodes are supplied so LogMiner can follow a failover.
configurable string cdcUsername = ?;
configurable string cdcPassword = ?;
configurable string cdbName = "TRADECDB";
configurable string pdbName = "TRADEPDB";
configurable string[] racNodes = ?;

configurable string riskEngineUrl = ?;
configurable int riskEvaluationMaxRetries = 2;
configurable decimal riskEvaluationRetryInitialDelay = 1;
configurable decimal riskEvaluationRetryBackoffFactor = 2;