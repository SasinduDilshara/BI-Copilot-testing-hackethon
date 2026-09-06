import ballerina/log;

public function main() returns error? {
    error? result = processOutgoingOrderFiles();
    if result is error {
        log:printError("Failed to process outgoing order files", result);
        return result;
    }
    log:printInfo("Order file processing run complete");
}
