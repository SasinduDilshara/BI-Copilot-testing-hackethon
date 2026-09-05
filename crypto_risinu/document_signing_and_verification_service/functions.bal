import ballerina/crypto;
import ballerina/lang.array;
import ballerina/time;

// Distinguishes an unknown trust-bundle alias (a client mistake — the
// caller named something that does not exist) from any other failure while
// resolving a certificate to verify against.
type UnknownAliasError distinct error;

// Carries the certificate's validity window so the caller can be told
// exactly when it was, or will be, valid. Distinct from a plain
// authenticity failure since the two mean very different things to the
// caller's workflow.
type CertificateExpiredError distinct error<record {|string notBefore; string notAfter;|}>;

// Produces a detached proof of origin for the given document bytes, signed
// with the identity held in the configured key bundle. The proof is encoded
// as base64 so it can be stored and transported as text alongside the file.
function signDocument(byte[] documentBytes) returns string|error {
    byte[] signatureBytes = check crypto:signRsaSha256(documentBytes, signingPrivateKey);
    return array:toBase64(signatureBytes);
}

// Verifies a document against a previously issued proof of origin, using the
// given public key. A non-matching proof is reported as `false`, a normal
// and expected outcome, not an error.
function verifyDocument(byte[] documentBytes, byte[] signatureBytes, crypto:PublicKey publicKey) returns boolean|error {
    return crypto:verifyRsaSha256Signature(documentBytes, signatureBytes, publicKey);
}

// Resolves the public key to verify a document against, based on what the
// caller supplied:
// - `certificatePem` takes a caller-supplied certificate as PEM text.
// - `certificateAlias` names one from the shared trust bundle; an unknown
//   alias is reported as an `UnknownAliasError`, a client mistake.
// - When neither is supplied, falls back to our own signing identity.
function resolveVerificationKey(string? certificatePem, string? certificateAlias) returns crypto:PublicKey|UnknownAliasError|error {
    if certificatePem is string {
        crypto:PublicKey|crypto:Error publicKey = crypto:decodeRsaPublicKeyFromContent(certificatePem.toBytes());
        if publicKey is crypto:Error {
            return error("The supplied certificate is not a valid PEM certificate.");
        }
        return publicKey;
    }

    if certificateAlias is string {
        crypto:TrustStore trustStore = {path: trustBundlePath, password: trustBundlePassword};
        crypto:PublicKey|crypto:Error publicKey = crypto:decodeRsaPublicKeyFromTrustStore(trustStore, certificateAlias);
        if publicKey is crypto:Error {
            return error UnknownAliasError("The named certificate alias was not found in the trust bundle.");
        }
        return publicKey;
    }

    return verificationPublicKey;
}

// Checks that a public key's certificate is within its validity window at
// the current moment. Returns a `CertificateExpiredError` carrying the
// window when it is not.
function requireCertificateCurrentlyValid(crypto:PublicKey publicKey) returns CertificateExpiredError|error? {
    crypto:Certificate? certificate = publicKey.certificate;
    if certificate is () {
        return error("The certificate to verify against has no validity information.");
    }

    time:Utc now = time:utcNow();
    if now < certificate.notBefore || now > certificate.notAfter {
        string notBefore = time:utcToString(certificate.notBefore);
        string notAfter = time:utcToString(certificate.notAfter);
        return error CertificateExpiredError("The certificate to verify against is outside its validity window.",
                notBefore = notBefore, notAfter = notAfter);
    }

    return ();
}

// Builds the identity information for our own signing certificate: who it
// was issued to, who issued it, and the window it is good for.
function ownSigningIdentity() returns IdentityInfo|error {
    crypto:Certificate? certificate = verificationPublicKey.certificate;
    if certificate is () {
        return error("The signing identity's certificate has no identity information.");
    }

    return {
        subject: certificate.subject,
        issuer: certificate.issuer,
        notBefore: time:utcToString(certificate.notBefore),
        notAfter: time:utcToString(certificate.notAfter)
    };
}
