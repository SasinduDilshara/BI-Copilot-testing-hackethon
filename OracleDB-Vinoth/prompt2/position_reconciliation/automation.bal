
import ballerina/lang.runtime;
import ballerina/log;

public function main() returns error? {
    while true {
        error? result = relayUnreconciledPositions();
        if result is error {
            log:printError("Position reconciliation poll failed", 'error = result);
        }
        runtime:sleep(pollIntervalSeconds);
    }
}