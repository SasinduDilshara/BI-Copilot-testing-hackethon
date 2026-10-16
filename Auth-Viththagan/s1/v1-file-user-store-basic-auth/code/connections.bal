import ballerina/auth;

// File user store based Basic Auth provider. Users, passwords, and scopes are
// sourced from the [[ballerina.auth.users]] section in Config.toml, never hardcoded here.
final auth:ListenerFileUserStoreBasicAuthProvider fileUserStoreBasicAuthProvider = new;
