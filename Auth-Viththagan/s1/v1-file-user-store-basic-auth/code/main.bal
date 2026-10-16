import ballerina/http;

listener http:Listener adminConsoleListener = new (servicePort);

service /admin on adminConsoleListener {

    # Returns the admin console dashboard summary.
    # Requires the authenticated user to have the "admin" scope.
    resource function get dashboard(http:Request request) returns json|http:Unauthorized|http:Forbidden {
        string|http:Unauthorized credential = extractBasicCredential(request);
        if credential is http:Unauthorized {
            return credential;
        }

        AdminUser|http:Unauthorized adminUser = authenticateUser(credential);
        if adminUser is http:Unauthorized {
            return adminUser;
        }

        http:Forbidden? forbidden = authorizeUser(adminUser, "admin");
        if forbidden is http:Forbidden {
            return forbidden;
        }

        return {
            message: "Welcome to the admin console",
            username: adminUser.username,
            scopes: adminUser.scopes
        };
    }

    # Returns the current admin console users' assigned scopes.
    # Requires the authenticated user to have either the "admin" or "viewer" scope.
    resource function get profile/scopes(http:Request request) returns json|http:Unauthorized|http:Forbidden {
        string|http:Unauthorized credential = extractBasicCredential(request);
        if credential is http:Unauthorized {
            return credential;
        }

        AdminUser|http:Unauthorized adminUser = authenticateUser(credential);
        if adminUser is http:Unauthorized {
            return adminUser;
        }

        http:Forbidden? forbidden = authorizeUser(adminUser, ["admin", "viewer"]);
        if forbidden is http:Forbidden {
            return forbidden;
        }

        return {
            username: adminUser.username,
            scopes: adminUser.scopes
        };
    }
}
