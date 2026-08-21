
import ballerinax/oracledb;
import ballerinax/oracledb.driver as _;
import ballerina/http;

// The DB firewall now requires TCPS. The DBA-provided Oracle Wallet (ewallet.p12) is a PKCS12
// file, so it is wired in directly as both the truststore (to trust the DB server's cert) and
// the keystore (in case the wallet also carries a client identity for mutual TLS).
final oracledb:Options claimsDbOptions = {
    ssl: {
        key: {
            path: dbWalletPath,
            password: dbWalletPassword
        },
        cert: {
            path: dbWalletPath,
            password: dbWalletPassword
        }
    }
};

final oracledb:Client claimsClient = check new (
    host = dbHost, port = dbPort, user = dbUser, password = dbPassword, database = dbService,
    options = claimsDbOptions
);

final http:Client clearinghouseClient = check new (clearinghouseApiUrl, timeout = 20);