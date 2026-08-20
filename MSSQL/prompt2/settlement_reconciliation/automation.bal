
import ballerina/log;

public function main() returns error? {
    check ensureSettlementSchema();

    SettlementRecord[] batch = check processorClient->get("/settlements/pending");
    error? result = insertSettlementBatch(batch);
    if result is error {
        log:printError("Settlement reconciliation run failed", 'error = result);
    }
}