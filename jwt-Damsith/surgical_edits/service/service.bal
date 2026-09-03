import ballerina/http;
import ballerina/jwt;

listener http:Listener claimsListener = new (servicePort);

// Validator configuration for bearer tokens minted by the broker portal's
// identity provider. Signature verification is done against the IdP's own
// certificate, so a token cannot be trusted unless the IdP actually signed
// it - crafting a plausible-looking payload is not enough to pass this.
final jwt:ValidatorConfig tokenValidatorConfig = {
    issuer: idpTokenIssuer,
    audience: idpTokenAudience,
    clockSkew: 60,
    signatureConfig: {
        certFile: idpCertPath
    }
};

// Verifies the inbound bearer token against the identity provider's
// certificate and expected issuer/audience before trusting anything inside
// it, then reads the caller identity off the validated sub claim.
function getCallerIdentity(http:Request request) returns string|error {
    string authHeader = check request.getHeader("Authorization");
    string token = authHeader.startsWith("Bearer ") ? authHeader.substring(7) : authHeader;
    jwt:Payload payload = check jwt:validate(token, tokenValidatorConfig);
    string? subject = payload.sub;
    if subject is () {
        return error("bearer token carries no sub claim");
    }
    return subject;
}

service /claims on claimsListener {

    // Accepts a claim from a broker and pushes it on to the partner network.
    // The claim is only recorded once the partner has acknowledged it, so a
    // failed forward leaves nothing half-written behind.
    resource function post .(http:Request request, ClaimSubmission submission)
            returns ClaimAck|http:BadRequest|http:Unauthorized|http:BadGateway {
        string|error callerId = getCallerIdentity(request);
        if callerId is error {
            ErrorDetail unauthorizedDetail = {message: "Missing or unreadable bearer token"};
            return <http:Unauthorized>{body: unauthorizedDetail};
        }

        string? validationFailure = validateSubmission(submission);
        if validationFailure is string {
            ErrorDetail badRequestDetail = {
                message: "Claim submission was rejected",
                details: validationFailure
            };
            return <http:BadRequest>{body: badRequestDetail};
        }

        string claimId = nextClaimId();
        ForwardedClaim claim = buildForwardedClaim(claimId, submission, callerId);
        PartnerClaimRequest partnerRequest = toPartnerRequest(claimId, submission, callerId);

        PartnerAck|error ack = forwardToPartner(partnerRequest);
        if ack is error {
            ErrorDetail badGatewayDetail = {
                message: "Partner network did not accept the claim",
                details: ack.message()
            };
            return <http:BadGateway>{body: badGatewayDetail};
        }

        ForwardedClaim stored = recordForwardedClaim(claim, ack);
        return {
            claimId: stored.claimId,
            status: stored.status,
            partnerReference: ack.reference
        };
    }

    // Lists the claims this caller has forwarded through us. Scoped to the
    // caller's own submissions so one broker never sees another's book.
    resource function get .(http:Request request)
            returns ForwardedClaim[]|http:Unauthorized {
        string|error callerId = getCallerIdentity(request);
        if callerId is error {
            ErrorDetail unauthorizedDetail = {message: "Missing or unreadable bearer token"};
            return <http:Unauthorized>{body: unauthorizedDetail};
        }
        ForwardedClaim[] callerClaims = from ForwardedClaim claim in forwardedClaims
            where claim.submittedBy == callerId
            select claim;
        return callerClaims;
    }

    // Returns one claim, refreshed against the partner network so the broker
    // sees the partner's current view rather than the status we stored at
    // submission time.
    resource function get [string claimId](http:Request request)
            returns ForwardedClaim|http:NotFound|http:Unauthorized|http:Forbidden {
        string|error callerId = getCallerIdentity(request);
        if callerId is error {
            ErrorDetail unauthorizedDetail = {message: "Missing or unreadable bearer token"};
            return <http:Unauthorized>{body: unauthorizedDetail};
        }

        ForwardedClaim? claim = getForwardedClaim(claimId);
        if claim is () {
            ErrorDetail notFoundDetail = {message: "Claim " + claimId + " was not found"};
            return <http:NotFound>{body: notFoundDetail};
        }

        if claim.submittedBy != callerId {
            ErrorDetail forbiddenDetail = {message: "Claim " + claimId + " belongs to another broker"};
            return <http:Forbidden>{body: forbiddenDetail};
        }

        string? partnerReference = claim.partnerReference;
        if partnerReference is () {
            return claim;
        }

        PartnerAck|error ack = fetchPartnerStatus(partnerReference);
        if ack is error {
            // Partner is unreachable right now - fall back to what we stored
            // rather than failing a read the broker can still act on.
            return claim;
        }
        return refreshClaimStatus(claim, ack);
    }
}
