import ballerina/time;

# Parses a pipe-delimited datagram payload into a `PlayerState` record.
# Expected format: playerId|x|y|direction|speed
#
# + payload - The raw datagram payload string
# + return - The parsed `PlayerState` or an error if the payload is invalid
function parsePlayerState(string payload) returns PlayerState|error {
    string:RegExp delimiter = re `\|`;
    string[] parts = delimiter.split(payload);
    if parts.length() != 5 {
        return error(string `Invalid payload format: ${payload}`);
    }

    string playerId = parts[0];
    decimal x = check decimal:fromString(parts[1]);
    decimal y = check decimal:fromString(parts[2]);
    string directionValue = parts[3];
    Direction direction = check directionValue.ensureType();
    decimal speed = check decimal:fromString(parts[4]);
    string lastUpdated = time:utcToString(time:utcNow());

    PlayerState playerState = {
        playerId: playerId,
        x: x,
        y: y,
        direction: direction,
        speed: speed,
        lastUpdated: lastUpdated
    };
    return playerState;
}
