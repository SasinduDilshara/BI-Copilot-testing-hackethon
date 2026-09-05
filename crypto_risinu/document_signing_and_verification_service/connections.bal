import ballerina/crypto;

// Location and credentials for the password-protected key bundle (PKCS#12)
// that holds the signing identity. Nothing here is ever revealed to a
// caller; only used locally to derive the keys at startup.
configurable string keyBundlePath = ?;
configurable string keyBundlePassword = ?;
configurable string keyAlias = ?;
configurable string keyPassword = ?;

// The private key used to produce detached signatures (proofs of origin).
// Derived once at module-init time so that a missing bundle, wrong
// passwords, or a missing alias fail the service at startup rather than on
// the first request.
final crypto:PrivateKey signingPrivateKey = check initSigningPrivateKey();

// The public key used to verify signatures, derived from the same bundle
// since the bundle holds the one identity used for both operations.
final crypto:PublicKey verificationPublicKey = check initVerificationPublicKey();

// Loads the private key from the configured key bundle. Any failure
// (missing file, wrong keystore/key password, missing alias) is wrapped into
// a sanitized error that carries no trace of the passwords or the bundle
// path, then surfaced immediately at startup.
function initSigningPrivateKey() returns crypto:PrivateKey|error {
    crypto:KeyStore keyStore = {path: keyBundlePath, password: keyBundlePassword};
    crypto:PrivateKey|error privateKey = crypto:decodeRsaPrivateKeyFromKeyStore(keyStore, keyAlias, keyPassword);

    if privateKey is error {
        return error("Failed to load the signing identity's private key from the configured key bundle.");
    }

    return privateKey;
}

// Loads the public key (certificate) from the configured key bundle, used to
// verify signatures produced with the corresponding private key.
function initVerificationPublicKey() returns crypto:PublicKey|error {
    crypto:TrustStore trustStore = {path: keyBundlePath, password: keyBundlePassword};
    crypto:PublicKey|error publicKey = crypto:decodeRsaPublicKeyFromTrustStore(trustStore, keyAlias);

    if publicKey is error {
        return error("Failed to load the signing identity's public key from the configured key bundle.");
    }

    return publicKey;
}
