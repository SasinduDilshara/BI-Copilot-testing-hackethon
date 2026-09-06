import ballerina/http;
import ballerina/jwt;

// Calls the existing credentials store to validate the caller's username and password.
// When actingDriverId is set, this is a depot manager standing in for that driver; the
// store is responsible for confirming the manager and driver share a depot before
// returning the combined result (driver identity plus the authenticated actor's identity).
function authenticateDriver(LoginRequest loginRequest) returns DriverAuthResult|http:ClientError {
    DriverAuthResult authResult = check credentialsStoreClient->/authenticate.post(loginRequest);
    return authResult;
}

// Issues a short-lived signed JWT that embeds the driver id, depot id, permissions, the
// acting identity/type (genuine driver vs a depot manager standing in), and confines the
// token to this issuer's region via the audience, so downstream services can authorize
// requests and enforce region scoping without calling back.
function issueDriverToken(DriverAuthResult driverAuthResult) returns string|jwt:Error {
    string regionScopedAudience = tokenAudience + ":" + tokenRegion;
    jwt:IssuerConfig issuerConfig = {
        issuer: tokenIssuer,
        username: driverAuthResult.driverId,
        audience: regionScopedAudience,
        expTime: tokenExpiryInSeconds,
        keyId: keystoreKeyAlias,
        customClaims: {
            driverId: driverAuthResult.driverId,
            depotId: driverAuthResult.depotId,
            permissions: driverAuthResult.permissions.toJson(),
            actorId: driverAuthResult.actorId,
            actorType: driverAuthResult.actorType,
            region: tokenRegion
        },
        signatureConfig: {
            algorithm: jwt:RS256,
            config: tokenSigningKey
        }
    };
    return jwt:issue(issuerConfig);
}
