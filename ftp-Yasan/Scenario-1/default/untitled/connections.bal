import ballerina/ftp;

final ftp:Client sftpClient = check new ({
    protocol: ftp:SFTP,
    host: sftpHost,
    port: sftpPort,
    auth: {
        credentials: {
            username: sftpUsername
        },
        privateKey: {
            path: sftpPrivateKeyPath
        }
    }
});
