import ballerinax/mongodb;

final mongodb:Client mongoClient = check new ({
    connection: {
        serverAddress: {
            host: mongoHost,
            port: mongoPort
        },
        auth: <mongodb:ScramSha256AuthCredential>{
            username: mongoUsername,
            password: mongoPassword,
            database: mongoAuthDatabase
        }
    },
    options: {
        sslEnabled: true,
        writeConcern: "majority",
        secureSocket: {
            keyStore: {
                path: mongoKeyStorePath,
                password: mongoKeyStorePassword
            },
            trustStore: {
                path: mongoTrustStorePath,
                password: mongoTrustStorePassword
            },
            protocol: "TLS"
        }
    }
});

final mongodb:Database supportDatabase = check getSupportDatabase();

final mongodb:Collection supportTicketsCollection = check getCollection(supportDatabase, "support_tickets");

final mongodb:Collection ticketAuditLogCollection = check getCollection(supportDatabase, "ticket_audit_log");

final mongodb:Collection chatEventsDlqCollection = check getCollection(supportDatabase, "chat_events_dlq");

function getSupportDatabase() returns mongodb:Database|error {
    mongodb:Database database = check mongoClient->getDatabase(mongoDatabaseName);
    return database;
}

function getCollection(mongodb:Database database, string collectionName) returns mongodb:Collection|error {
    mongodb:Collection collection = check database->getCollection(collectionName);
    return collection;
}
