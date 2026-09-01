// Represents the direction a player is currently facing/moving towards.
public type Direction "north"|"south"|"east"|"west";

# Represents an incoming move request from an HTTP client.
#
# + playerId - Unique identifier of the player
# + x - X coordinate of the player
# + y - Y coordinate of the player
# + direction - Current direction of the player
# + speed - Current speed of the player
public type MoveRequest record {|
    string playerId;
    decimal x;
    decimal y;
    Direction direction;
    decimal speed;
|};
