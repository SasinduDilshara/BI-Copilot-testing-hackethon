import ballerinax/mssql;
import ballerinax/mssql.driver as _;
import ballerina/http;
import ballerina/sql;

final mssql:Client settlementClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbName
);

final http:Client processorClient = check new (processorApiUrl, timeout = 15);

# Ensures the settlements table has a unique constraint on settlementId so that
# re-inserts of an already-committed record are rejected by the database instead
# of creating duplicate rows, and that the dead-letter table exists.
function ensureSettlementSchema() returns error? {
    sql:ExecutionResult|sql:Error constraintResult = settlementClient->execute(`
        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes
            WHERE name = 'UQ_settlements_settlementId' AND object_id = OBJECT_ID('settlements')
        )
        ALTER TABLE settlements ADD CONSTRAINT UQ_settlements_settlementId UNIQUE (settlementId)
    `);
    if constraintResult is sql:Error {
        return constraintResult;
    }

    sql:ExecutionResult|sql:Error dlqTableResult = settlementClient->execute(`
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'settlements_dlq')
        CREATE TABLE settlements_dlq (
            settlementId VARCHAR(100) NOT NULL,
            storeId VARCHAR(100) NOT NULL,
            amount DECIMAL(18, 2) NOT NULL,
            batchDate VARCHAR(50) NOT NULL,
            failureReason VARCHAR(1000) NULL,
            deadLetteredAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
        )
    `);
    if dlqTableResult is sql:Error {
        return dlqTableResult;
    }
}
