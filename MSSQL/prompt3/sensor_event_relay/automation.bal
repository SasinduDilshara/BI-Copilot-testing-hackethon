
import ballerina/lang.runtime;
import ballerina/log;

public function main() returns error? {
    while true {
        error? eastResult = relayUnprocessed(eastPlantClient);
        if eastResult is error {
            log:printError("East plant relay failed", 'error = eastResult);
        }
        error? westResult = relayUnprocessed(westPlantClient);
        if westResult is error {
            log:printError("West plant relay failed", 'error = westResult);
        }
        runtime:sleep(pollIntervalSeconds);
    }
}