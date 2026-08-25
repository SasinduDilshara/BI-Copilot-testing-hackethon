import ballerina/auth;
import ballerina/http;
import ballerina/lang.array;

# Extracts the Basic Auth credential (Base64-encoded `username:password`) from the
# `Authorization` header of the incoming request.
#
# + request - The inbound HTTP request
# + return - The Base64-encoded credential portion, or an `http:Unauthorized` if the header
#            is missing or not a Basic Auth header
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

    return authorizationHeader.substring(basicPrefix.length());
}

# Authenticates the given Basic Auth credential against the file user store.
#
# + credential - The Base64-encoded `username:password` credential
# + return - The authenticated user's details (including scopes) or an `http:Unauthorized`
public isolated function authenticateUser(string credential) returns AdminUser|http:Unauthorized {
    auth:UserDetails|auth:Error userDetails = fileUserStoreBasicAuthProvider.authenticate(credential);
    if userDetails is auth:Error {
        return {body: "Invalid username or password"};
    }
    AdminUser adminUser = {username: userDetails.username, scopes: userDetails.scopes};
    return adminUser;
}

# Authorizes the authenticated user against the expected scope(s).
#
# + adminUser - The authenticated user details
# + expectedScopes - The scope or scopes required to access the resource
# + return - `()` if authorized, or an `http:Forbidden` if the user does not have the required scope
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
