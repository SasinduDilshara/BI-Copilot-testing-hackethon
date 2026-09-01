import ballerina/log;
import ballerina/udp;

// In-memory store of the latest state per player, guarded by lock blocks.
isolated map<PlayerState> playerStates = {};

service on new udp:Listener(7000) {

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
