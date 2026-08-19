
import ballerina/lang.runtime;
import ballerina/log;

public function main() returns error? {
    while true {
        error? result = processUnreconciled();
        if result is error {
            log:printError("Reconciliation poll failed", 'error = result);
        }
        runtime:sleep(pollIntervalSeconds);
    }
}