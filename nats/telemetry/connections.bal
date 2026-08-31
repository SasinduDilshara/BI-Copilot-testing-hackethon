import ballerinax/nats;

// TLS configuration securing the connection to the NATS server using a truststore.
final nats:SecureSocket telemetrySecureSocket = {
    cert: {
        path: tlsTrustStorePath,
        password: tlsTrustStorePassword
    }
};

// Username/password authentication credentials for the NATS server.
final nats:Credentials telemetryAuthCredentials = {
    username: natsUsername,
    password: natsPassword
};

// Shared NATS client used to publish alerts. noEcho is enabled so this connection never
// receives back the alert messages it publishes to telemetry.alerts, even though the
// listener below subscribes to telemetry.> which would otherwise include that subject.
final nats:Client natsClient = check new (natsUrl, connectionName = connectionName, auth = telemetryAuthCredentials,
    secureSocket = telemetrySecureSocket, noEcho = true);

