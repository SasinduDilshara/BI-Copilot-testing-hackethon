
import ballerina/sql;
import ballerina/log;

// Oracle's batchExecute does not behave like SQL Server's: when a command in the batch fails,
// the whole batch is returned as a single sql:BatchExecuteError and the underlying transaction
// is not committed. So none of the rows in a failed batch can be assumed to be persisted.
// On failure we fall back to executing each claim line individually so the exact bad row(s)
// can be isolated, and only those specific rows are dead-lettered.
const string UNIQUE_CONSTRAINT_SQL_STATE = "23000";

function insertClaimLineBatch(ClaimLine[] lines) returns error? {
    if lines.length() == 0 {
        return;
    }

    sql:ParameterizedQuery[] queries = from ClaimLine l in lines
        select `INSERT INTO claim_lines (claimLineId, claimId, procedureCode, billedAmount)
                VALUES (${l.claimLineId}, ${l.claimId}, ${l.procedureCode}, ${l.billedAmount})`;

    sql:ExecutionResult[]|sql:Error batchResult = claimsClient->batchExecute(queries);
    if batchResult is sql:Error {
        log:printError("Claim line batch insert failed, nothing in this batch was committed. " +
                "Retrying each claim line individually to isolate the bad row(s)", 'error = batchResult);
        check retryClaimLinesIndividually(lines);
    }
}

// Retries each claim line with its own execute call so a single bad row cannot block the rest,
// and dead-letters only the rows that actually fail on this isolated retry.
function retryClaimLinesIndividually(ClaimLine[] lines) returns error? {
    DeadLetterClaimLine[] deadLetterLines = [];

    foreach ClaimLine line in lines {
        sql:ParameterizedQuery insertQuery = `INSERT INTO claim_lines (claimLineId, claimId, procedureCode, billedAmount)
                VALUES (${line.claimLineId}, ${line.claimId}, ${line.procedureCode}, ${line.billedAmount})`;
        sql:ExecutionResult|sql:Error lineResult = claimsClient->execute(insertQuery);
        if lineResult is sql:Error {
            string failureReason = lineResult.message();
            if isUniqueConstraintViolation(lineResult) {
                failureReason = "Duplicate claimLineId rejected by unique constraint: " + failureReason;
            }
            log:printError("Claim line failed on isolated retry, sending to dead-letter queue",
                    'error = lineResult, claimLineId = line.claimLineId);
            deadLetterLines.push({...line, failureReason});
        }
    }

    if deadLetterLines.length() > 0 {
        check dispatchToDeadLetterQueue(deadLetterLines);
    }
}

// Inserts the given claim lines into claim_lines_dlq. Each row is inserted individually so that
// a problem with one dead-lettered row does not prevent the others from being recorded.
function dispatchToDeadLetterQueue(DeadLetterClaimLine[] deadLetterLines) returns error? {
    foreach DeadLetterClaimLine deadLetterLine in deadLetterLines {
        sql:ParameterizedQuery dlqInsertQuery = `INSERT INTO claim_lines_dlq (claimLineId, claimId, procedureCode, billedAmount, failureReason)
                VALUES (${deadLetterLine.claimLineId}, ${deadLetterLine.claimId}, ${deadLetterLine.procedureCode},
                        ${deadLetterLine.billedAmount}, ${deadLetterLine.failureReason})`;
        sql:ExecutionResult|sql:Error dlqResult = claimsClient->execute(dlqInsertQuery);
        if dlqResult is sql:Error {
            log:printError("Failed to dead-letter claim line", 'error = dlqResult, claimLineId = deadLetterLine.claimLineId);
        }
    }
}

// Oracle reports a unique constraint violation (ORA-00001) as a DatabaseError with SQL state 23000.
function isUniqueConstraintViolation(sql:Error err) returns boolean {
    if err is sql:DatabaseError {
        sql:DatabaseErrorDetail detail = err.detail();
        return detail.sqlState == UNIQUE_CONSTRAINT_SQL_STATE;
    }
    return false;
}

// ORA-02275/ORA-00955/ORA-02264: raised when the constraint (or an equivalent one) already exists,
// which happens on every run after the first. This is expected and safe to ignore.
const int ORACLE_CONSTRAINT_ALREADY_EXISTS = -2275;
const int ORACLE_NAME_ALREADY_USED_BY_OBJECT = -955;

// Ensures claimLineId can never be duplicated at the database level, so a re-processed or
// double-submitted claim line is rejected outright instead of silently inserted again.
// This is idempotent: it is safe to call on every run.
function ensureClaimLineConstraintsExist() returns error? {
    sql:ExecutionResult|sql:Error constraintResult = claimsClient->execute(`
        ALTER TABLE claim_lines ADD CONSTRAINT uq_claim_lines_claim_line_id UNIQUE (claimLineId)`);
    if constraintResult is sql:Error {
        if constraintResult is sql:DatabaseError {
            sql:DatabaseErrorDetail detail = constraintResult.detail();
            if detail.errorCode == ORACLE_CONSTRAINT_ALREADY_EXISTS || detail.errorCode == ORACLE_NAME_ALREADY_USED_BY_OBJECT {
                return;
            }
        }
        return constraintResult;
    }
}