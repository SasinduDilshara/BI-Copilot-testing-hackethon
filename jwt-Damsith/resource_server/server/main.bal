import ballerina/http;

// JWT validator configuration shared by every resource. The signing keys are
// never bundled with the build — they are fetched live from the corporate
// IdP's JWKS endpoint (and cached in memory) so key rotation on the IdP side
// is picked up automatically without redeploying this service.
final http:JwtValidatorConfig idpJwtValidatorConfig = {
    issuer: idpIssuer,
    audience: idpAudience,
    clockSkew: 60,
    signatureConfig: {
        jwksConfig: {
            url: idpJwksUrl
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
