import ballerina/crypto;
import ballerina/http;

// Client used to validate driver credentials against the existing credentials store.
final http:Client credentialsStoreClient = check new (credentialsStoreBaseUrl);

// Private key decoded from the PKI-issued PKCS#12 keystore, used to sign issued JWTs.
final crypto:PrivateKey tokenSigningKey = check crypto:decodeRsaPrivateKeyFromKeyStore(
    {
        path: keystorePath,
        password: keystorePassword
    },
    keystoreKeyAlias,
    keystoreKeyPassword
);
