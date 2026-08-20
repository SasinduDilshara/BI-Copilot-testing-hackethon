
import ballerina/log;
import ballerinax/cdc;

// Reacts to new positions as soon as they land, instead of polling every few seconds.
service cdc:Service on positionsCdcListener {

    remote function onCreate(record {} after, string tableName) returns error? {
        Position pos = check after.cloneWithType(Position);
        check evaluatePositionWithRetry(pos);
    }

    remote function onError(cdc:Error err) {
        log:printError("Positions CDC listener error", 'error = err);
    }
}