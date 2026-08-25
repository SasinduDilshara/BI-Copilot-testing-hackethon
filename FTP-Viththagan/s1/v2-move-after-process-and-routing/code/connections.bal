import ballerina/ftp;

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
    }
});
