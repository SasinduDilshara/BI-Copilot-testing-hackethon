import ballerina/http;

service /game on new http:Listener(8081) {

    resource function get players() returns PlayerState[] {
        lock {
            return playerStates.toArray().clone();
        }
    }

    resource function get players/[string playerId]() returns PlayerState|http:NotFound {
        lock {
            if playerStates.hasKey(playerId) {
                return playerStates.get(playerId).clone();
            }
        }
        return {
            body: string `Player with ID '${playerId}' not found`
        };
    }
}
