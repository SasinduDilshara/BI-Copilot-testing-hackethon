import ballerina/smb;

// Shared SMB connection settings for both the listener and the client.
final smb:AuthConfiguration smbAuthConfig = {
    credentials: {
        username: smbUsername,
        password: smbPassword,
        domain: smbDomain
    }
};

// Listens on the /inbound directory of the share for incoming order files.
listener smb:Listener orderIntakeListener = check new ({
    host: smbHost,
    port: smbPort,
    share: smbShareName,
    auth: smbAuthConfig,
    fileNamePattern: "^orders-\\d{8}\\.csv$"
});

// Used to upload the processed summary JSON back to the share.
final smb:Client orderIntakeClient = check new ({
    host: smbHost,
    port: smbPort,
    share: smbShareName,
    auth: smbAuthConfig
});
