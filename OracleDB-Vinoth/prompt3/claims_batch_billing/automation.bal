
import ballerina/log;

public function main() returns error? {
    check ensureClaimLineConstraintsExist();

    ClaimLine[] pendingLines = check clearinghouseClient->get("/claims/pending-lines");
    error? result = insertClaimLineBatch(pendingLines);
    if result is error {
        log:printError("Claims batch billing run failed", 'error = result);
    }
}