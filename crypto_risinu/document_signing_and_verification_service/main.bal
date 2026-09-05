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

    // Verifies a document against a previously issued proof of origin. A
    // proof that does not match is reported calmly as "not authentic"
    // rather than as an error. A proof that is not valid base64 is a client
    // error.
    resource function post verify(@http:Payload DocumentVerificationRequest verificationRequest)
            returns VerifyResult|http:BadRequest|http:InternalServerError {
        string document = verificationRequest.document;
        string proof = verificationRequest.proof;

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

        boolean|error verificationResult = verifyDocument(documentBytes, signatureBytes);
        if verificationResult is error {
            return <http:InternalServerError>{
                body: {message: "Unable to verify the document at this time."}
            };
        }

        return {authentic: verificationResult};
    }
}
