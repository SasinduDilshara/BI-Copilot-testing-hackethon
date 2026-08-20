
import ballerina/sql;
import ballerina/http;

function relayUnreconciledPositions() returns error? {
    stream<Position, sql:Error?> positions = positionsClient->query(
        `SELECT position_id as positionId, book, instrument_id as instrumentId,
                quantity, mark_price as markPrice FROM positions WHERE reconciled = 0`);
    check from Position pos in positions
        do {
            http:Response _ = check riskEngineClient->post("/positions/evaluate", pos);
            _ = check positionsClient->execute(
                `UPDATE positions SET reconciled = 1 WHERE position_id = ${pos.positionId}`);
        };
}