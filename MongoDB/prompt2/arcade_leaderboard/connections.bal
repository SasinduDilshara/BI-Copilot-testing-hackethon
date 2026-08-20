
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
        writeConcern: "majoriy" // <- typo, meant "majority"
    }
});

final mongodb:Database arcadeDb = check mongoClient->getDatabase(mongoDbName);