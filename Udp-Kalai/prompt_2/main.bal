import ballerina/log;
import ballerina/task;
import ballerina/time;
import ballerina/udp;

// In-memory store of the latest state per player, guarded by lock blocks.
isolated map<PlayerState> playerStates = {};

// Total number of UDP packets received since the server started.
isolated int totalPacketsReceived = 0;

// The UTC time the server started, used to compute uptime.
final time:Utc serverStartTime = time:utcNow();

// The maximum duration, in seconds, a player can remain inactive before being removed.
const decimal SESSION_TIMEOUT_SECONDS = 30;

// The interval, in seconds, at which the stale-player cleanup job runs.
const decimal CLEANUP_INTERVAL_SECONDS = 10;

service on new udp:Listener(7000, localHost = "0.0.0.0") {

    remote function onDatagram(readonly & udp:Datagram datagram, udp:Caller caller) returns udp:Error? {
        string|error payload = string:fromBytes(datagram.data);
        if payload is error {
            log:printError("Failed to decode datagram payload", payload);
            return;
        }

        PlayerState|error playerState = parsePlayerState(payload);
        if playerState is error {
            log:printError("Failed to parse player state payload", playerState);
            return;
        }

        lock {
            playerStates[playerState.playerId] = playerState.clone();
        }

        lock {
            totalPacketsReceived += 1;
        }

        string confirmation = string `OK|${playerState.playerId}|${playerState.x}|${playerState.y}`;
        udp:Datagram response = {
            remoteHost: datagram.remoteHost,
            remotePort: datagram.remotePort,
            data: confirmation.toBytes()
        };
        check caller->sendDatagram(response);
    }

    remote function onError(udp:Error err) {
        log:printError("Error occurred in the UDP listener", err);
    }
}

# Scheduled job that removes players whose last update is older than the session timeout.
class PlayerSessionCleanupJob {
    *task:Job;

    public function execute() {
        time:Utc currentTime = time:utcNow();

        lock {
            string[] stalePlayerIds = [];
            foreach PlayerState playerState in playerStates {
                time:Utc|error lastUpdatedTime = time:utcFromString(playerState.lastUpdated);
                if lastUpdatedTime is error {
                    log:printError("Failed to parse lastUpdated timestamp", lastUpdatedTime);
                    continue;
                }
                time:Seconds elapsedSeconds = time:utcDiffSeconds(currentTime, lastUpdatedTime);
                if elapsedSeconds > SESSION_TIMEOUT_SECONDS {
                    stalePlayerIds.push(playerState.playerId);
                }
            }
            foreach string playerId in stalePlayerIds {
                _ = playerStates.removeIfHasKey(playerId);
            }
        }
    }
}

function init() returns error? {
    task:JobId _ = check task:scheduleJobRecurByFrequency(new PlayerSessionCleanupJob(), CLEANUP_INTERVAL_SECONDS);
}
