
import ballerina/sql;
import ballerina/log;

function insertSettlementBatch(SettlementRecord[] records) returns error? {
    sql:ParameterizedQuery[] queries = from SettlementRecord r in records
        select `INSERT INTO settlements (settlementId, storeId, amount, batchDate)
                VALUES (${r.settlementId}, ${r.storeId}, ${r.amount}, ${r.batchDate})`;
    sql:ExecutionResult[]|sql:Error result = settlementClient->batchExecute(queries);
    if result is sql:Error {
        log:printError("Batch insert failed, retrying whole batch", 'error = result);
        // naive retry of the entire batch
        _ = check settlementClient->batchExecute(queries);
    }
}