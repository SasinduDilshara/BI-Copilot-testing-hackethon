
configurable string mongoHost = ?;
configurable int mongoPort = 27017;
configurable string mongoUser = ?;
configurable string mongoPassword = ?;
configurable string mongoAuthDb = "admin";
configurable string mongoDbName = "arcade";

configurable string kafkaBootstrapServers = "localhost:9092";
configurable string kafkaScoreSubmissionsTopic = "score-submissions";
configurable string kafkaConsumerGroupId = "arcade-leaderboard-score-consumers";