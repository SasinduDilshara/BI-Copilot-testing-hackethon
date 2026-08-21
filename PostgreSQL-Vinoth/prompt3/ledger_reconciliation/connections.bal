
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;
import ballerinax/postgresql.cdc.driver as _;
import ballerina/http;
import ballerina/email;

final postgresql:Client ledgerClient = check new (
    host = dbHost, port = dbPort, username = dbUser, password = dbPassword, database = dbName
);

final http:Client reconciliationClient = check new (reconciliationApiUrl, timeout = 10);

final email:SmtpClient alertSmtpClient = check new (alertSmtpHost, alertSmtpUsername, alertSmtpPassword);

listener postgresql:CdcListener ledgerCdcListener = new (database = {
    hostname: dbHost,
    port: dbPort,
    username: dbUser,
    password: dbPassword,
    databaseName: dbName,
    includedTables: ["public.ledger_entries"],
    excludedColumns: ["public.ledger_entries.account_holder_ssn"],
    replicationConfig: {
        slotName: ledgerCdcSlotName,
        slotDropOnStop: false
    },
    publicationConfig: {
        publicationName: ledgerCdcPublicationName,
        publicationAutocreateMode: postgresql:FILTERED
    }
}, options = {
    heartbeatConfig: {
        interval: ledgerCdcHeartbeatIntervalSeconds
    }
});