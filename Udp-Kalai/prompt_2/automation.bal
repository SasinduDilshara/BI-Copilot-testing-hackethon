import ballerina/http;
import ballerina/time;

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

    resource function get session/stats() returns SessionStats {
        int activePlayers;
        lock {
            activePlayers = playerStates.length();
        }

        int packetsReceived;
        lock {
            packetsReceived = totalPacketsReceived;
        }

        time:Seconds uptime = time:utcDiffSeconds(time:utcNow(), serverStartTime);
        SessionStats sessionStats = {
            activePlayers: activePlayers,
            totalPacketsReceived: packetsReceived,
            uptimeSeconds: <int>uptime
        };
        return sessionStats;
    }
}
