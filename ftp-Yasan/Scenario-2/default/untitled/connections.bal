import ballerina/ftp;

final ftp:AuthConfiguration sftpAuth = {
    credentials: {username: sftpUsername},
    privateKey: {
        path: sftpPrivateKeyPath,
        password: sftpPrivateKeyPassword
    }
};

listener ftp:Listener orderIntakeListener = check new ({
    protocol: ftp:SFTP,
    host: sftpHost,
    port: sftpPort,
    auth: sftpAuth
});

final ftp:Client orderIntakeClient = check new ({
    protocol: ftp:SFTP,
    host: sftpHost,
    port: sftpPort,
    auth: sftpAuth
});
