
configurable string dbHost = ?;
configurable int dbPort = 1521;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbService = ?;

// Oracle Wallet (ewallet.p12), supplied by the DBA for the TCPS-only firewall path.
// The wallet's PKCS12 file doubles as both the truststore (server trust) and, when it carries
// a client identity, the keystore (client cert) - so it is referenced directly here.
configurable string dbWalletPath = ?;
configurable string dbWalletPassword = ?;

configurable string clearinghouseApiUrl = ?;