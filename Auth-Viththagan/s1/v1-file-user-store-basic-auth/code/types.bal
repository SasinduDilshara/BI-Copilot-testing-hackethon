import ballerina/auth;

# Represents the authenticated admin console user along with their authorized scopes.
public type AdminUser record {|
    *auth:UserDetails;
|};
