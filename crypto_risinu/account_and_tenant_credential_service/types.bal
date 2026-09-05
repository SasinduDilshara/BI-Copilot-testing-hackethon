// Request payload for registration and login. The password field is never
// logged, stored in plain form, or echoed back in any response.
public type Credentials record {|
    string username;
    string password;
|};

// Generic success/failure response. Deliberately contains no trace of the
// password or anything derived from it.
public type AuthResult record {|
    string message;
|};

// Declares how expensive password verification should be for every account
// under a tenant. lowCost favors cheap/fast checks (high-volume tenants);
// highCost favors deliberately expensive checks (regulated tenants).
public enum PasswordPolicy {
    LOW_COST = "lowCost",
    HIGH_COST = "highCost"
}

// Request payload for onboarding a new tenant.
public type TenantRegistration record {|
    string tenantId;
    PasswordPolicy passwordPolicy;
|};

// Response returned once when a tenant is onboarded. This is the only place
// the derived tenant secret is revealed; we never store it ourselves, it is
// re-derived on demand from the master secret plus the tenant id.
public type TenantRegistrationResult record {|
    string tenantId;
    string tenantSecret;
|};

// Response listing the usernames owned by the authenticated tenant.
public type AccountList record {|
    string[] usernames;
|};

// Internal representation of a stored account. Only the password hash is
// kept; the plaintext password is never retained. Accounts are keyed by
// tenant so the same username can exist independently under different
// tenants.
type Account record {|
    string tenantId;
    string username;
    string passwordHash;
|};

// Internal representation of an onboarded tenant. Only the declared password
// policy is stored; the tenant secret itself is never persisted, it is
// re-derived from the master secret whenever it is needed.
type Tenant record {|
    string tenantId;
    PasswordPolicy passwordPolicy;
|};
