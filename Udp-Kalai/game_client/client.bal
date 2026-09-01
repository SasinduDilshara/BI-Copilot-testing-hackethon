import ballerina/udp;

configurable string remoteHost = "localhost";
configurable int remotePort = 7000;
configurable decimal connectTimeout = 10;

# Sends a player position update to the game server over UDP and returns the
# server's confirmation response.
#
# + playerId - Unique identifier of the player
# + x - X coordinate of the player
# + y - Y coordinate of the player
# + direction - Current direction of the player
# + speed - Current speed of the player
# + return - The decoded confirmation response from the server, or an error
function sendPositionUpdate(string playerId, decimal x, decimal y, Direction direction, decimal speed) returns string|error {
    udp:ConnectClient socketClient = check new (remoteHost, remotePort, timeout = connectTimeout);

    string payload = string `${playerId}|${x}|${y}|${direction}|${speed}`;
    check socketClient->writeBytes(payload.toBytes());

    byte[] & readonly response = check socketClient->readBytes();
    string confirmation = check string:fromBytes(response);

    check socketClient->close();
    return confirmation;
}
