import ballerina/auth;

# Represents the authenticated admin console user along with their authorized scopes.
public type AdminUser record {|
    *auth:UserDetails;
|};

# Represents a single file-user-store entry configured in Config.toml, where the
# password is stored as a BCrypt hash rather than plaintext.
public type HashedUserStoreEntry record {|
    readonly string username;
    string passwordHash;
    string[] scopes;
|};
