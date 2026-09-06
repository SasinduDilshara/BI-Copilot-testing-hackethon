import ballerina/smb;

// Client for the partner's SMB/CIFS file share used to exchange order files.
final smb:Client partnerShareClient = check new ({
    host: smbHost,
    port: smbPort,
    share: smbShare,
    auth: {
        credentials: {
            username: smbUsername,
            password: smbPassword,
            domain: smbDomain
        }
    }
});
