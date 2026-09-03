import ballerina/http;
import ballerina/jwt;

// Calls the existing credentials store to validate a driver's username and password.
// Returns the driver's identity, depot, and permissions on success.
function authenticateDriver(LoginRequest loginRequest) returns DriverAuthResult|http:ClientError {
    DriverAuthResult authResult = check credentialsStoreClient->/authenticate.post(loginRequest);
    return authResult;
}

// Issues a short-lived signed JWT that embeds the driver id, depot id, and permissions
// as custom claims, so downstream services can authorize requests without calling back.
function issueDriverToken(DriverAuthResult driverAuthResult) returns string|jwt:Error {
    jwt:IssuerConfig issuerConfig = {
        issuer: tokenIssuer,
        username: driverAuthResult.driverId,
        audience: tokenAudience,
        expTime: tokenExpiryInSeconds,
        keyId: keystoreKeyAlias,
        customClaims: {
            driverId: driverAuthResult.driverId,
            depotId: driverAuthResult.depotId,
            permissions: driverAuthResult.permissions.toJson()
        },
        signatureConfig: {
            algorithm: jwt:RS256,
            config: tokenSigningKey
        }
    };
    return jwt:issue(issuerConfig);
}
