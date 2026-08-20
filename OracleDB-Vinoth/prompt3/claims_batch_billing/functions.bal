
import ballerina/sql;
import ballerina/log;

function insertClaimLineBatch(ClaimLine[] lines) returns error? {
    sql:ParameterizedQuery[] queries = from ClaimLine l in lines
        select `INSERT INTO claim_lines (claimLineId, claimId, procedureCode, billedAmount)
                VALUES (${l.claimLineId}, ${l.claimId}, ${l.procedureCode}, ${l.billedAmount})`;
    sql:ExecutionResult[]|sql:Error result = claimsClient->batchExecute(queries);
    if result is sql:Error {
        // assumes the batch partially succeeded and only failed rows need re-inserting
        log:printError("Some claim lines failed, will retry the batch as-is next run", 'error = result);
    }
}