
import ballerinax/mongodb;

final mongodb:Client mongoClient = check new ({
    connection: {
        serverAddress: {host: mongoHost, port: mongoPort},
        auth: <mongodb:ScramSha256AuthCredential>{
            username: mongoUser,
            password: mongoPassword,
            database: mongoAuthDb
        }
    },
    options: {
        // "majority" ensures the write is acknowledged by a majority of the
        // replica set members (durable across a primary failover) before the
        // driver treats it as successful. The previous value ("majoriy") was
        // an unrecognized write concern, which caused the driver behavior for
        // unacknowledged/undefined write concern instead of majority durability.
        writeConcern: "majority",
        retryWrites: true
    }
});

function getArcadeDatabase() returns mongodb:Database|error {
    mongodb:Database database = check mongoClient->getDatabase(mongoDbName);
    return database;
}

final mongodb:Database arcadeDb = check getArcadeDatabase();

function getScoresCollection() returns mongodb:Collection|error {
    mongodb:Collection collection = check arcadeDb->getCollection("player_scores");
    return collection;
}

function getScoresDlqCollection() returns mongodb:Collection|error {
    mongodb:Collection collection = check arcadeDb->getCollection("scores_dlq");
    return collection;
}

final mongodb:Collection scoresCollection = check getScoresCollection();

final mongodb:Collection scoresDlqCollection = check getScoresDlqCollection();

function initScoreIndexes() returns error? {
    mongodb:DatabaseError|mongodb:ApplicationError|error|() result = scoresCollection->createIndex(
        {playerId: 1, levelId: 1},
        {unique: true, name: "uniq_player_level"}
    );
    if result is error {
        return result;
    }
}

final error? scoreIndexInitResult = initScoreIndexes();