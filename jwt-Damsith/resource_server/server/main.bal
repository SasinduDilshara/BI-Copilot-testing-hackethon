import ballerina/http;

// Keycloak's realm base issuer, per the current realm path layout
// (/realms/{realm-name}/...) documented at
// https://www.keycloak.org/securing-apps/oidc-layers (Keycloak 26.7.x).
final string idpRealmBaseUrl = string `${idpBaseUrl}/realms/${idpRealm}`;

// JWT validator configuration shared by every resource. The signing keys are
// never bundled with the build — they are fetched live from Keycloak's realm
// certificate (JWKS) endpoint and held in an in-memory cache for
// jwksCacheTtlSeconds, so key rotation on the Keycloak side (old key goes
// passive, new key becomes active) is picked up on the next fetch after the
// cache entry expires — no redeploy needed, and no per-request call to the
// IdP either.
final http:JwtValidatorConfig idpJwtValidatorConfig = {
    issuer: idpRealmBaseUrl,
    audience: idpAudience,
    clockSkew: jwtClockSkewSeconds,
    signatureConfig: {
        jwksConfig: {
            url: string `${idpRealmBaseUrl}/protocol/openid-connect/certs`,
            cacheConfig: {
                defaultMaxAge: jwksCacheTtlSeconds,
                capacity: 10
            }
        }
    }
};

listener http:Listener claimsListener = new (servicePort);

@http:ServiceConfig {
    auth: [
        {
            jwtValidatorConfig: idpJwtValidatorConfig
        }
    ]
}
service /claims on claimsListener {

    // Low sensitivity: list all claims. Requires the claims:read scope.
    @http:ResourceConfig {
        auth: [
            {
                jwtValidatorConfig: idpJwtValidatorConfig,
                scopes: ["claims:read"]
            }
        ]
    }
    resource function get .() returns ClaimSummary[]|http:Unauthorized|http:Forbidden {
        return getAllClaimSummaries();
    }

    // Low sensitivity: view a single claim's status. Requires the claims:read scope.
    @http:ResourceConfig {
        auth: [
            {
                jwtValidatorConfig: idpJwtValidatorConfig,
                scopes: ["claims:read"]
            }
        ]
    }
    resource function get [string claimId]() returns ClaimStatus|http:NotFound|http:Unauthorized|http:Forbidden {
        ClaimStatus? claim = getClaimById(claimId);
        if claim is () {
            ErrorDetail notFoundDetail = {message: string `Claim ${claimId} was not found`};
            return <http:NotFound>{body: notFoundDetail};
        }
        return claim;
    }

    // High sensitivity: approve a payout. Requires the elevated claims:approve scope.
    @http:ResourceConfig {
        auth: [
            {
                jwtValidatorConfig: idpJwtValidatorConfig,
                scopes: ["claims:approve"]
            }
        ]
    }
    resource function post [string claimId]/approve(http:Request request) returns ClaimDecision|http:NotFound|http:Unauthorized|http:Forbidden|error {
        string decidedBy = check getCallerSubject(request);
        ClaimDecision? decision = approveClaimById(claimId, decidedBy);
        if decision is () {
            ErrorDetail notFoundDetail = {message: string `Claim ${claimId} was not found`};
            return <http:NotFound>{body: notFoundDetail};
        }
        return decision;
    }

    // High sensitivity: reject a claim. Requires the elevated claims:approve scope.
    @http:ResourceConfig {
        auth: [
            {
                jwtValidatorConfig: idpJwtValidatorConfig,
                scopes: ["claims:approve"]
            }
        ]
    }
    resource function post [string claimId]/reject(http:Request request) returns ClaimDecision|http:NotFound|http:Unauthorized|http:Forbidden|error {
        string decidedBy = check getCallerSubject(request);
        ClaimDecision? decision = rejectClaimById(claimId, decidedBy);
        if decision is () {
            ErrorDetail notFoundDetail = {message: string `Claim ${claimId} was not found`};
            return <http:NotFound>{body: notFoundDetail};
        }
        return decision;
    }
}
