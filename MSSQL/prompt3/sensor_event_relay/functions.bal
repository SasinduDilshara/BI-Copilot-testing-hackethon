
import ballerinax/mssql;
import ballerina/sql;
import ballerina/http;

function relayUnprocessed(mssql:Client dbClient) returns error? {
    stream<SensorEvent, sql:Error?> events = dbClient->query(
        `SELECT eventId, sensorId, reading, recordedAt FROM sensor_events WHERE processed = 0`);
    check from SensorEvent evt in events
        do {
            http:Response _ = check analyticsClient->post("/sensor-events", evt);
            _ = check dbClient->execute(
                `UPDATE sensor_events SET processed = 1 WHERE eventId = ${evt.eventId}`);
        };
}