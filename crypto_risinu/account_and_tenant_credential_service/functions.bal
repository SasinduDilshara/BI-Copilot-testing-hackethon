import ballerina/crypto;
import ballerina/http;
import ballerina/log;

const int MINIMUM_PASSWORD_LENGTH = 12;

const string GENERIC_SERVER_ERROR_MESSAGE = "Something went wrong. Please try again later.";
const string INVALID_LOGIN_MESSAGE = "Invalid username or password.";
const string UNAUTHORIZED_TENANT_MESSAGE = "Unauthorized.";

// Standard password hashing parameters: memory-hard Argon2id, tuned so a
// single verification costs meaningful work on the server. This is the one
// and only password storage scheme; every account, regardless of tenant, is
// held to this same standard.
const int ARGON2_ITERATIONS = 6;
const int ARGON2_MEMORY_KB = 131072;
const int ARGON2_PARALLELISM = 4;

// Prefix that identifies a hash produced by the legacy PBKDF2 scheme that
// used to be offered as a low-cost option. Used only to detect accounts that
// still need to be transparently upgraded to Argon2id.
const string LEGACY_PBKDF2_HASH_PREFIX = "$pbkdf2-";

// Builds the composite key used to look up an account, scoping usernames to
// their owning tenant.
function accountKey(string tenantId, string username) returns string => tenantId + ":" + username;

// Hashes a password using the single standard scheme.
function hashPassword(string password) returns string|error {
    return crypto:hashArgon2(password, iterations = ARGON2_ITERATIONS, memory = ARGON2_MEMORY_KB,
            parallelism = ARGON2_PARALLELISM);
}

// Verifies a password against a stored hash. Stored hashes self-describe
// their algorithm and parameters, so legacy PBKDF2 hashes left over from
// before the standardization are still verified correctly; they are then
// upgraded by the caller on successful login.
function verifyPassword(string password, string passwordHash) returns boolean|error {
    if isLegacyHash(passwordHash) {
        return crypto:verifyPbkdf2(password, passwordHash);
    }

    return crypto:verifyArgon2(password, passwordHash);
}

// Reports whether a stored hash was produced by the retired PBKDF2 scheme
// and therefore still needs to be upgraded to the current standard.
function isLegacyHash(string passwordHash) returns boolean {
    return passwordHash.startsWith(LEGACY_PBKDF2_HASH_PREFIX);
}

// Produces a hash in the retired PBKDF2 format. Not used anywhere in the
// running service; retained solely so tests can fabricate a pre-existing
// legacy-hashed account to exercise the silent upgrade path.
function hashWithLegacyScheme(string password) returns string|error {
    return crypto:hashPbkdf2(password);
}

// Derives a tenant's secret from the master secret and the tenant id, as raw
// bytes. Nothing per-tenant is ever stored; the secret is reconstructed on
// demand from the single master secret held in configuration.
function deriveTenantSecretBytes(string tenantId) returns byte[]|error {
    return crypto:hmacSha256(tenantId.toBytes(), masterSecret.toBytes());
}

// Derives a tenant's secret and returns it hex-encoded, the form handed to
// the tenant once at onboarding time.
function deriveTenantSecretHex(string tenantId) returns string|error {
    byte[] secretBytes = check deriveTenantSecretBytes(tenantId);
    return secretBytes.toBase16();
}

// Computes the hex-encoded HMAC-SHA256 proof of tenant identity for a given
// request body, keyed by the tenant's derived secret. This is the same
// computation a legitimate caller performs to produce the X-Tenant-Proof
// header value.
function computeTenantProofHex(string tenantId, string requestBody) returns string|error {
    byte[] tenantSecretBytes = check deriveTenantSecretBytes(tenantId);
    byte[] proofBytes = check crypto:hmacSha256(requestBody.toBytes(), tenantSecretBytes);
    return proofBytes.toBase16();
}

// Onboards a new tenant. Rejects duplicate tenant ids. Returns the tenant's
// derived secret so it can be handed over; this is the only time the secret
// is revealed.
function registerTenant(string tenantId) returns TenantRegistrationResult|error {
    if tenantStore.hasKey(tenantId) {
        return error("Tenant id is already registered");
    }

    Tenant newTenant = {tenantId};
    tenantStore[tenantId] = newTenant;

    string tenantSecret = check deriveTenantSecretHex(tenantId);
    return {tenantId, tenantSecret};
}

// Verifies the machine-to-machine proof of tenant identity carried on a
// request: a hex-encoded HMAC-SHA256 over the raw request body, keyed by the
// tenant's derived secret. Runs the full derive-and-compare path even for an
// unrecognized tenant id, using a decoy secret, so that an unknown tenant and
// a known tenant with a wrong proof take the same code path and the same
// time. The comparison itself is constant-time.
function verifyTenantProof(string tenantId, string requestBody, string? providedProofHex) returns boolean|error {
    Tenant? existingTenant = tenantStore[tenantId];
    byte[] tenantSecretBytes = existingTenant is Tenant ? check deriveTenantSecretBytes(tenantId) : decoyTenantSecretBytes;

    byte[] expectedProofBytes = check crypto:hmacSha256(requestBody.toBytes(), tenantSecretBytes);
    string expectedProofHex = expectedProofBytes.toBase16();

    string proofToCompare = providedProofHex is string ? providedProofHex : "";
    boolean proofMatches = crypto:equalConstantTime(proofToCompare, expectedProofHex);

    return existingTenant is Tenant && proofMatches;
}

// Registers a new account under a tenant. Validates the password length
// first, before doing anything else (including before checking whether the
// username exists), then rejects duplicate usernames within the tenant, then
// hashes and stores the password using the single standard scheme.
function registerAccount(string tenantId, string username, string password) returns AuthResult|error {
    if password.length() < MINIMUM_PASSWORD_LENGTH {
        return error("Password does not meet the minimum length requirement");
    }

    string key = accountKey(tenantId, username);
    if accountStore.hasKey(key) {
        return error("Username is already taken");
    }

    string passwordHash = check hashPassword(password);
    Account newAccount = {tenantId, username, passwordHash};
    accountStore[key] = newAccount;

    return {message: "Registration successful."};
}

// Authenticates an account under a tenant. Always performs a hash
// verification, even when the username is unknown, and always returns the
// same outcome/message for "unknown username" and "wrong password" so
// callers cannot distinguish the two cases through the response or through
// timing. On a successful login against an account still holding a legacy
// hash, the password is silently rehashed with the current standard scheme
// and the stored hash is upgraded in place, with no forced reset.
function authenticateAccount(string tenantId, string username, string password) returns boolean|error {
    string key = accountKey(tenantId, username);
    Account? existingAccount = accountStore[key];

    string hashToVerify = existingAccount is Account ? existingAccount.passwordHash : decoyPasswordHash;
    boolean passwordMatches = check verifyPassword(password, hashToVerify);

    boolean loginSucceeded = existingAccount is Account && passwordMatches;

    if loginSucceeded && existingAccount is Account && isLegacyHash(existingAccount.passwordHash) {
        string upgradedHash = check hashPassword(password);
        Account upgradedAccount = {tenantId, username, passwordHash: upgradedHash};
        accountStore[key] = upgradedAccount;
    }

    return loginSucceeded;
}

// Lists the usernames owned by a tenant. Only ever called after the tenant
// proof has already been verified.
function listTenantUsernames(string tenantId) returns string[] {
    string[] usernames = from Account account in accountStore
        where account.tenantId == tenantId
        select account.username;

    return usernames;
}

// Logs the real cause of an unexpected failure server-side while a generic
// message is returned to the caller.
function logInternalError(string context, error cause) {
    log:printError(context, 'error = cause);
}

// Enforces machine-to-machine tenant authentication for a resource. Reads the
// raw request body (the same bytes the caller signed), verifies the supplied
// proof, and returns the tenant id on success. A missing/malformed/wrong
// proof and an unrecognized tenant id all produce the exact same
// http:Unauthorized value, with no distinguishing message and no shortcut
// that would skip the constant-time comparison.
function requireValidTenant(string tenantId, string? tenantProof, http:Request request) returns string|http:Unauthorized|error {
    string requestBody = "";
    string|http:ClientError textPayload = request.getTextPayload();
    if textPayload is string {
        requestBody = textPayload;
    }

    boolean isAuthenticatedTenant = check verifyTenantProof(tenantId, requestBody, tenantProof);

    if isAuthenticatedTenant {
        return tenantId;
    }

    return <http:Unauthorized>{
        body: {message: UNAUTHORIZED_TENANT_MESSAGE}
    };
}
