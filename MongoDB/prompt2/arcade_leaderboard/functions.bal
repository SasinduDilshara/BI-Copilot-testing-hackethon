
import ballerinax/mongodb;

function recordHighScore(ScoreSubmission submission) returns error? {
    mongodb:Collection scores = check arcadeDb->getCollection("player_scores");
    mongodb:UpdateResult _ = check scores->updateOne(
        {playerId: submission.playerId, levelId: submission.levelId},
        {max: {score: submission.score}, setOnInsert: {playerId: submission.playerId, levelId: submission.levelId}},
        {upsert: true}
    );
}