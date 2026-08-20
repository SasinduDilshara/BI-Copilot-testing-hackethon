
import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;

// Forwards a position to the risk engine, retrying on failure with exponential backoff.
// If every attempt fails, the position is written to the positions_reconciliation_dlq table.
function evaluatePositionWithRetry(Position pos) returns error? {
    decimal retryDelay = riskEvaluationRetryInitialDelay;
    int attempt = 0;
    while true {
        http:Response|error response = riskEngineClient->post("/positions/evaluate", pos);
        if response is http:Response {
            return;
        }
        attempt += 1;
        if attempt > riskEvaluationMaxRetries {
            log:printError("Risk evaluation failed after retries, sending to DLQ",
                    'error = response, positionId = pos.positionId);
            check writeToDlq(pos, response.message());
            return;
        }
        log:printWarn("Risk evaluation attempt failed, retrying",
                'error = response, positionId = pos.positionId, attempt = attempt);
        runtime:sleep(retryDelay);
        retryDelay = retryDelay * riskEvaluationRetryBackoffFactor;
    }
}

function writeToDlq(Position pos, string failureReason) returns error? {
    PositionReconciliationDlqEntry dlqEntry = {
        positionId: pos.positionId,
        book: pos.book,
        instrumentId: pos.instrumentId,
        quantity: pos.quantity,
        markPrice: pos.markPrice,
        tradeNotes: pos.tradeNotes,
        failureReason: failureReason
    };
    _ = check positionsClient->execute(
        `INSERT INTO positions_reconciliation_dlq
            (position_id, book, instrument_id, quantity, mark_price, trade_notes, failure_reason)
         VALUES (${dlqEntry.positionId}, ${dlqEntry.book}, ${dlqEntry.instrumentId},
                 ${dlqEntry.quantity}, ${dlqEntry.markPrice}, ${dlqEntry.tradeNotes}, ${dlqEntry.failureReason})`);
}