// The single master secret from which every tenant secret is derived. This is
// the only secret held in configuration; onboarding a tenant only ever hands
// out its derived value, nothing is added to config.
configurable string masterSecret = ?;

// In-memory account store: "tenantId:username" -> Account. This is
// process-local state, as required for this internal admin tool (no external
// persistence).
final map<Account> accountStore = {};

// In-memory tenant store: tenantId -> Tenant. Holds only the tenant's
// declared password policy; the tenant secret itself is never stored here,
// it is re-derived from the master secret whenever it is needed.
final map<Tenant> tenantStore = {};

// Pre-computed decoy password hashes, one per policy, with no corresponding
// real account. When a login is attempted for a username that does not
// exist, we still run a verify against the matching decoy so the response
// time and outcome are indistinguishable from a wrong-password case,
// preventing username enumeration.
final string decoyPasswordHashLowCost = check hashWithPolicy("decoy-password-value", LOW_COST);
final string decoyPasswordHashHighCost = check hashWithPolicy("decoy-password-value", HIGH_COST);

// A decoy tenant secret used to keep the tenant-proof check's timing and code
// path identical when the caller's tenant id is not recognized, preventing
// tenant enumeration through the authentication step.
final byte[] decoyTenantSecretBytes = check deriveTenantSecretBytes("unrecognized-tenant-decoy");
