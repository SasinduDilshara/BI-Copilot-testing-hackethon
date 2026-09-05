import ballerina/crypto;
import ballerina/http;
import ballerina/log;

const int MINIMUM_PASSWORD_LENGTH = 12;

const string GENERIC_SERVER_ERROR_MESSAGE = "Something went wrong. Please try again later.";
const string INVALID_LOGIN_MESSAGE = "Invalid username or password.";
const string UNAUTHORIZED_TENANT_MESSAGE = "Unauthorized.";

// Low-cost policy parameters: a small PBKDF2 iteration count keeps each login
// check cheap for high-volume tenants.
const int LOW_COST_PBKDF2_ITERATIONS = 10000;

// High-cost policy parameters: memory-hard Argon2id with elevated cost
// parameters makes each login check deliberately expensive for regulated
// tenants.
const int HIGH_COST_ARGON2_ITERATIONS = 6;
const int HIGH_COST_ARGON2_MEMORY_KB = 131072;
const int HIGH_COST_ARGON2_PARALLELISM = 4;

// Builds the composite key used to look up an account, scoping usernames to
// their owning tenant.
function accountKey(string tenantId, string username) returns string => tenantId + ":" + username;

// Hashes a password according to the given tenant policy.
function hashWithPolicy(string password, PasswordPolicy passwordPolicy) returns string|error {
    if passwordPolicy == LOW_COST {
        return crypto:hashPbkdf2(password, iterations = LOW_COST_PBKDF2_ITERATIONS);
    }

    return crypto:hashArgon2(password, iterations = HIGH_COST_ARGON2_ITERATIONS, memory = HIGH_COST_ARGON2_MEMORY_KB,
            parallelism = HIGH_COST_ARGON2_PARALLELISM);
}

// Verifies a password against a stored hash according to the given tenant
// policy. Both hashing schemes self-describe their parameters in the stored
// hash string, so the verify side only needs to know which algorithm to use.
function verifyWithPolicy(string password, string passwordHash, PasswordPolicy passwordPolicy) returns boolean|error {
    if passwordPolicy == LOW_COST {
        return crypto:verifyPbkdf2(password, passwordHash);
    }

    return crypto:verifyArgon2(password, passwordHash);
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

// Onboards a new tenant with its declared password policy. Rejects duplicate
// tenant ids. Returns the tenant's derived secret so it can be handed over;
// this is the only time the secret is revealed.
function registerTenant(string tenantId, PasswordPolicy passwordPolicy) returns TenantRegistrationResult|error {
    if tenantStore.hasKey(tenantId) {
        return error("Tenant id is already registered");
    }

    Tenant newTenant = {tenantId, passwordPolicy};
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

// Looks up a tenant's declared password policy. Only ever called after the
// tenant proof has already been verified, so the tenant is known to exist.
function getTenantPasswordPolicy(string tenantId) returns PasswordPolicy|error {
    Tenant? existingTenant = tenantStore[tenantId];
    if existingTenant is Tenant {
        return existingTenant.passwordPolicy;
    }

    return error("Unknown tenant id");
}

// Registers a new account under a tenant. Validates the password length
// first, before doing anything else (including before checking whether the
// username exists), then rejects duplicate usernames within the tenant, then
// hashes and stores the password using the tenant's declared policy.
function registerAccount(string tenantId, string username, string password) returns AuthResult|error {
    if password.length() < MINIMUM_PASSWORD_LENGTH {
        return error("Password does not meet the minimum length requirement");
    }

    string key = accountKey(tenantId, username);
    if accountStore.hasKey(key) {
        return error("Username is already taken");
    }

    PasswordPolicy passwordPolicy = check getTenantPasswordPolicy(tenantId);
    string passwordHash = check hashWithPolicy(password, passwordPolicy);
    Account newAccount = {tenantId, username, passwordHash};
    accountStore[key] = newAccount;

    return {message: "Registration successful."};
}

// Authenticates an account under a tenant. Always performs a hash
// verification, even when the username is unknown, and always returns the
// same outcome/message for "unknown username" and "wrong password" so
// callers cannot distinguish the two cases through the response or through
// timing.
function authenticateAccount(string tenantId, string username, string password) returns boolean|error {
    PasswordPolicy passwordPolicy = check getTenantPasswordPolicy(tenantId);

    string key = accountKey(tenantId, username);
    Account? existingAccount = accountStore[key];

    string decoyPasswordHash = passwordPolicy == LOW_COST ? decoyPasswordHashLowCost : decoyPasswordHashHighCost;
    string hashToVerify = existingAccount is Account ? existingAccount.passwordHash : decoyPasswordHash;
    boolean passwordMatches = check verifyWithPolicy(password, hashToVerify, passwordPolicy);

    return existingAccount is Account && passwordMatches;
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
