
configurable string dbHost = ?;
configurable int dbPort = 5432;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbName = "core_banking";

configurable string reconciliationApiUrl = ?;

configurable string ledgerCdcSlotName = "ledger_reconciliation_slot";
configurable string ledgerCdcPublicationName = "ledger_cdc_pub";
configurable decimal ledgerCdcHeartbeatIntervalSeconds = 300;

configurable string alertSmtpHost = ?;
configurable string alertSmtpUsername = ?;
configurable string alertSmtpPassword = ?;
configurable string alertFromAddress = ?;
configurable string alertToAddress = ?;