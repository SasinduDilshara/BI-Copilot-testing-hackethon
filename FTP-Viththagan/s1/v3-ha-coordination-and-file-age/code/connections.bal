import ballerina/ftp;
import ballerina/task;

// Coordination database configuration shared by all listener instances in the
// same coordination group, used to elect a single active poller while the
// remaining instances stay in warm standby.
task:MysqlConfig coordinationDatabaseConfig = {
    host: coordinationDbHost,
    port: coordinationDbPort,
    user: coordinationDbUser,
    password: coordinationDbPassword,
    database: coordinationDbName
};

listener ftp:Listener orderFileListener = check new ({
    protocol: ftp:SFTP,
    host: sftpHost,
    port: sftpPort,
    auth: {
        credentials: {
            username: sftpUsername
        },
        privateKey: {
            path: sftpPrivateKeyPath,
            password: sftpPrivateKeyPassword
        }
    },
    sftpSshKnownHosts: sftpKnownHostsPath,
    pollingInterval: pollingInterval,
    csvFailSafe: {
        contentType: ftp:RAW_AND_METADATA
    },
    coordination: {
        databaseConfig: coordinationDatabaseConfig,
        memberId: coordinationMemberId,
        coordinationGroup: coordinationGroup,
        heartbeatFrequency: coordinationHeartbeatFrequency,
        livenessCheckInterval: coordinationLivenessCheckInterval
    }
});
