import ballerina/http;

// Response returned after successfully signing a document. Contains the
// detached proof of origin (a base64-encoded digital signature) that the
// caller stores alongside the original document bytes.
public type SignResult record {|
    string proof;
|};

// Request payload for verification: the document bytes and the proof to
// check it against, both carried as base64 text so they fit cleanly into a
// JSON request body. The certificate to verify against is optional: supply
// `certificatePem` to check against a caller-supplied certificate, or
// `certificateAlias` to name one from the shared trust bundle. When neither
// is given, verification falls back to our own signing identity.
public type DocumentVerificationRequest record {|
    string document;
    string proof;
    string certificatePem?;
    string certificateAlias?;
|};

// Response returned after verifying a document against a proof. This is a
// normal, expected outcome regardless of whether the document is authentic,
// so a non-matching proof is reported here rather than as an error.
public type VerifyResult record {|
    boolean authentic;
|};

// Response returned when verification cannot proceed because the
// certificate being verified against is outside its validity window at the
// moment of the request. Deliberately a distinct shape/status from both a
// malformed request and a normal "not authentic" outcome, since a stale
// certificate and a failed authenticity check mean very different things to
// the caller's workflow.
public type CertificateNotValid record {|
    *http:UnprocessableEntity;
    record {|string message; string notBefore; string notAfter;|} body;
|};

// Response describing our own signing identity: who it was issued to, who
// issued it, and the window it is good for. Never contains the private key,
// the bundle path, or any password.
public type IdentityInfo record {|
    string subject;
    string issuer;
    string notBefore;
    string notAfter;
|};

// Generic error payload used for client and server error responses. Never
// contains the signing identity's passwords or the key bundle path.
public type ErrorDetails record {|
    string message;
|};
