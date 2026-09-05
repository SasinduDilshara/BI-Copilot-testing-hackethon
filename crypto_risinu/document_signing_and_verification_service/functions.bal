import ballerina/crypto;
import ballerina/lang.array;

// Produces a detached proof of origin for the given document bytes, signed
// with the identity held in the configured key bundle. The proof is encoded
// as base64 so it can be stored and transported as text alongside the file.
function signDocument(byte[] documentBytes) returns string|error {
    byte[] signatureBytes = check crypto:signRsaSha256(documentBytes, signingPrivateKey);
    return array:toBase64(signatureBytes);
}

// Verifies a document against a previously issued proof of origin. A
// non-matching proof is reported as `false`, a normal and expected outcome,
// not an error. Only a structurally invalid proof (not valid base64) or an
// unexpected internal failure is surfaced as an error to the caller.
function verifyDocument(byte[] documentBytes, byte[] signatureBytes) returns boolean|error {
    return crypto:verifyRsaSha256Signature(documentBytes, signatureBytes, verificationPublicKey);
}
