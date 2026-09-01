// Represents the direction a player is currently facing/moving towards.
public type Direction "north"|"south"|"east"|"west";

# Represents the latest known state of a player.
#
# + playerId - Unique identifier of the player
# + x - X coordinate of the player
# + y - Y coordinate of the player
# + direction - Current direction of the player
# + speed - Current speed of the player
# + lastUpdated - Timestamp string of the last update
public type PlayerState record {|
    string playerId;
    decimal x;
    decimal y;
    Direction direction;
    decimal speed;
    string lastUpdated;
|};
