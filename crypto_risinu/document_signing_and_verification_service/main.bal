import ballerina/crypto;
import ballerina/http;
import ballerina/lang.array;

configurable int servicePort = 8080;

service /documents on new http:Listener(servicePort) {

    // Stamps the given document bytes, returning a detached proof of origin
    // produced with the identity held in the configured key bundle. The
    // caller stores this proof alongside the original document.
    resource function post sign(@http:Payload byte[] document)
            returns SignResult|http:InternalServerError {
        string|error proof = signDocument(document);

        if proof is string {
            return {proof};
        }

        return <http:InternalServerError>{
            body: {message: "Unable to sign the document at this time."}
        };
    }

    // Verifies a document against a previously issued proof of origin using
    // the quantum-resistant ML-DSA-65 scheme. The certificate to check
    // against can be the caller's own PEM text, one named by alias from the
    // shared trust bundle, or (when neither is given) our own signing
    // identity — all must carry an ML-DSA-65 identity. A proof that does
    // not match is reported calmly as "not authentic" rather than as an
    // error. A proof or document that is not valid base64 is a client
    // error, as is an unknown alias or a certificate that isn't a usable
    // ML-DSA-65 identity. A certificate that is outside its validity window
    // at the moment of the request is refused, distinctly from both of
    // those and from a normal "not authentic" outcome.
    resource function post verify(@http:Payload DocumentVerificationRequest verificationRequest)
            returns VerifyResult|http:BadRequest|CertificateNotValid|http:InternalServerError {
        string document = verificationRequest.document;
        string proof = verificationRequest.proof;
        string? certificatePem = verificationRequest.certificatePem;
        string? certificateAlias = verificationRequest.certificateAlias;

        byte[]|error documentBytes = array:fromBase64(document);
        if documentBytes is error {
            return <http:BadRequest>{
                body: {message: "The document is not valid base64."}
            };
        }

        byte[]|error signatureBytes = array:fromBase64(proof);
        if signatureBytes is error {
            return <http:BadRequest>{
                body: {message: "The proof is not valid base64."}
            };
        }

        crypto:PublicKey|UnknownAliasError|error verificationKey = resolveVerificationKey(certificatePem, certificateAlias);
        if verificationKey is UnknownAliasError {
            return <http:BadRequest>{
                body: {message: "The named certificate alias was not found in the trust bundle."}
            };
        }
        if verificationKey is error {
            return <http:BadRequest>{
                body: {message: "The supplied certificate is not a usable quantum-resistant (ML-DSA-65) certificate."}
            };
        }

        CertificateExpiredError|error? validityCheck = requireCertificateCurrentlyValid(verificationKey);
        if validityCheck is CertificateExpiredError {
            record {|string notBefore; string notAfter;|} validityWindow = validityCheck.detail();
            return <CertificateNotValid>{
                body: {
                    message: "The certificate to verify against is outside its validity window.",
                    notBefore: validityWindow.notBefore,
                    notAfter: validityWindow.notAfter
                }
            };
        }
        if validityCheck is error {
            return <http:InternalServerError>{
                body: {message: "Unable to verify the document at this time."}
            };
        }

        boolean|error verificationResult = verifyDocument(documentBytes, signatureBytes, verificationKey);
        if verificationResult is error {
            return <http:InternalServerError>{
                body: {message: "Unable to verify the document at this time."}
            };
        }

        return {authentic: verificationResult};
    }

    // Reports who our own signing identity actually is: who it was issued
    // to, who issued it, and the window it is good for.
    resource function get identity() returns IdentityInfo|http:InternalServerError {
        IdentityInfo|error identityInfo = ownSigningIdentity();

        if identityInfo is error {
            return <http:InternalServerError>{
                body: {message: "Unable to read the signing identity at this time."}
            };
        }

        return identityInfo;
    }
}
