// Response returned after successfully signing a document. Contains the
// detached proof of origin (a base64-encoded digital signature) that the
// caller stores alongside the original document bytes.
public type SignResult record {|
    string proof;
|};

// Request payload for verification: the document bytes and the proof to
// check it against, both carried as base64 text so they fit cleanly into a
// JSON request body.
public type DocumentVerificationRequest record {|
    string document;
    string proof;
|};

// Response returned after verifying a document against a proof. This is a
// normal, expected outcome regardless of whether the document is authentic,
// so a non-matching proof is reported here rather than as an error.
public type VerifyResult record {|
    boolean authentic;
|};

// Generic error payload used for client and server error responses. Never
// contains the signing identity's passwords or the key bundle path.
public type ErrorDetails record {|
    string message;
|};
