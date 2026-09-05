import ballerina/crypto;

// In-memory account store: username -> Account. This is process-local state,
// as required for this internal admin tool (no external persistence).
final map<Account> accountStore = {};

// A pre-computed Argon2 hash with no corresponding real account. When a login
// is attempted for a username that does not exist, we still run a verify
// against this hash so the response time and outcome are indistinguishable
// from a wrong-password case, preventing username enumeration.
final string decoyPasswordHash = check crypto:hashArgon2("decoy-password-value");
