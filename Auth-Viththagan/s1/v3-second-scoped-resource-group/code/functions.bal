import ballerina/auth;
import ballerina/crypto;
import ballerina/http;
import ballerina/lang.array;
import ballerina/log;

# Extracts the Basic Auth credential (Base64-encoded `username:password`) from the
# `Authorization` header of the incoming request.
#
# + request - The inbound HTTP request
# + return - The Base64-encoded credential portion, or an `http:Unauthorized` if the header
#            is missing, empty, or not a well-formed Basic Auth header
public isolated function extractBasicCredential(http:Request request) returns string|http:Unauthorized {
    string authorizationHeader;
    do {
        authorizationHeader = check request.getHeader("Authorization");
    } on fail {
        return {body: "Authorization header is missing"};
    }

    string basicPrefix = "Basic ";
    if !authorizationHeader.startsWith(basicPrefix) {
        return {body: "Authorization header is not a Basic Auth header"};
    }

    string credential = authorizationHeader.substring(basicPrefix.length()).trim();
    if credential.length() == 0 {
        return {body: "Basic Auth credential is empty"};
    }

    return credential;
}

# Authenticates the given Basic Auth credential against the file user store, verifying the
# password using its BCrypt hash. Credentials, hashes, and scopes are sourced solely from
# Config.toml (`adminConsoleUsers`) — never hardcoded.
#
# Security note: `auth:ListenerFileUserStoreBasicAuthProvider` (the built-in file user store
# provider) only supports plaintext password comparison and cannot verify hashed passwords,
# so it is intentionally not used here. Verification is instead performed explicitly with
# `crypto:verifyBcrypt` against the configured `passwordHash`.
#
# + credential - The Base64-encoded `username:password` credential
# + return - The authenticated user's details (including scopes) or an `http:Unauthorized`
public isolated function authenticateUser(string credential) returns AdminUser|http:Unauthorized {
    [string, string]|auth:Error decoded = auth:extractUsernameAndPassword(credential);
    if decoded is auth:Error {
        // Malformed Base64 or missing ':' separator - do not leak the underlying error.
        return {body: "Invalid Basic Auth credential"};
    }

    [string, string] [username, password] = decoded;
    HashedUserStoreEntry? userEntry = adminConsoleUsers[username];
    if userEntry is () {
        return {body: "Invalid username or password"};
    }

    boolean|crypto:Error passwordMatches = crypto:verifyBcrypt(password, userEntry.passwordHash);
    if passwordMatches is crypto:Error {
        log:printError("Password verification failed", 'error = passwordMatches);
        return {body: "Invalid username or password"};
    }
    if !passwordMatches {
        return {body: "Invalid username or password"};
    }

    AdminUser adminUser = {username: userEntry.username, scopes: userEntry.scopes};
    return adminUser;
}

# Authorizes the authenticated user against the expected scope(s). The authenticated user's
# scopes (exposed via `AdminUser`) are checked against the scopes required by the handler.
#
# + adminUser - The authenticated user details
# + expectedScopes - The scope or scopes required to access the resource
# + return - `()` if authorized, or an `http:Forbidden` (HTTP 403) if the user is authenticated
#            but does not have the required scope
public isolated function authorizeUser(AdminUser adminUser, string|string[] expectedScopes) returns http:Forbidden? {
    string[]? userScopes = adminUser.scopes;
    if userScopes is () {
        return {body: "User does not have any assigned scopes"};
    }

    string[] requiredScopes;
    if expectedScopes is string {
        requiredScopes = [expectedScopes];
    } else {
        requiredScopes = expectedScopes;
    }

    foreach string requiredScope in requiredScopes {
        if array:indexOf(userScopes, requiredScope) is int {
            return;
        }
    }
    return {body: "User does not have the required scope to access this resource"};
}

# Runs the full authentication and scope-based authorization flow for an `/admin/**`
# resource: extracts the Basic credential, authenticates it against the file user store,
# then authorizes the authenticated user against the expected scope(s).
#
# + request - The inbound HTTP request
# + expectedScopes - The scope or scopes required to access the resource
# + return - The authenticated and authorized `AdminUser`, an `http:Unauthorized` (HTTP 401)
#            if the credential is missing, malformed, or invalid, or an `http:Forbidden`
#            (HTTP 403) if the user is authenticated but lacks the required scope
public isolated function authenticateAndAuthorize(http:Request request, string|string[] expectedScopes)
    returns AdminUser|http:Unauthorized|http:Forbidden {
    string|http:Unauthorized credential = extractBasicCredential(request);
    if credential is http:Unauthorized {
        return credential;
    }

    AdminUser|http:Unauthorized adminUser = authenticateUser(credential);
    if adminUser is http:Unauthorized {
        return adminUser;
    }

    http:Forbidden? forbidden = authorizeUser(adminUser, expectedScopes);
    if forbidden is http:Forbidden {
        return forbidden;
    }

    return adminUser;
}
