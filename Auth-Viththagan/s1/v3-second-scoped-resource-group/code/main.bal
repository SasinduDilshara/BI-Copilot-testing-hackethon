import ballerina/http;

listener http:Listener adminConsoleListener = new (servicePort);

service /admin on adminConsoleListener {

    # Returns the admin console dashboard summary.
    # Requires the authenticated user to have the "admin" scope.
    resource function get dashboard(http:Request request) returns json|http:Unauthorized|http:Forbidden {
        AdminUser|http:Unauthorized|http:Forbidden result = authenticateAndAuthorize(request, "admin");
        if result is http:Unauthorized|http:Forbidden {
            return result;
        }

        return {
            message: "Welcome to the admin console",
            username: result.username,
            scopes: result.scopes
        };
    }

    # Returns the current admin console user's assigned scopes.
    # Requires the authenticated user to have the "admin" scope.
    resource function get profile/scopes(http:Request request) returns json|http:Unauthorized|http:Forbidden {
        AdminUser|http:Unauthorized|http:Forbidden result = authenticateAndAuthorize(request, "admin");
        if result is http:Unauthorized|http:Forbidden {
            return result;
        }

        return {
            username: result.username,
            scopes: result.scopes
        };
    }
}

service /reports on adminConsoleListener {

    # Returns the finance reports summary.
    # Requires the authenticated user to have the "finance" scope.
    resource function get summary(http:Request request) returns json|http:Unauthorized|http:Forbidden {
        AdminUser|http:Unauthorized|http:Forbidden result = authenticateAndAuthorize(request, "finance");
        if result is http:Unauthorized|http:Forbidden {
            return result;
        }

        return {
            message: "Welcome to the finance reports console",
            username: result.username,
            scopes: result.scopes
        };
    }
}
