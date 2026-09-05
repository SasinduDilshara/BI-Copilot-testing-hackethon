import ballerina/http;

configurable int servicePort = 8080;

service /auth on new http:Listener(servicePort) {

    // Onboards a new tenant with its declared password policy. Returns the
    // tenant's derived secret once; nothing else is needed to complete
    // onboarding and no per-tenant secret is added to configuration.
    resource function post tenants(@http:Payload TenantRegistration tenantRegistration)
            returns TenantRegistrationResult|http:BadRequest|http:InternalServerError {
        string tenantId = tenantRegistration.tenantId;
        PasswordPolicy passwordPolicy = tenantRegistration.passwordPolicy;

        TenantRegistrationResult|error registrationResult = registerTenant(tenantId, passwordPolicy);

        if registrationResult is TenantRegistrationResult {
            return registrationResult;
        }

        string errorMessage = registrationResult.message();
        if errorMessage == "Tenant id is already registered" {
            return <http:BadRequest>{
                body: {message: "Tenant id is already registered."}
            };
        }

        logInternalError("Unexpected failure during tenant registration", registrationResult);
        return <http:InternalServerError>{
            body: {message: GENERIC_SERVER_ERROR_MESSAGE}
        };
    }

    // Registers a new account under the authenticated tenant. Rejects short
    // passwords and duplicate usernames. Never echoes the password or any
    // derived value.
    resource function post accounts(@http:Header {name: "X-Tenant-Id"} string xTenantId,
            @http:Header {name: "X-Tenant-Proof"} string? xTenantProof, http:Request request,
            @http:Payload Credentials credentials)
            returns AuthResult|http:BadRequest|http:Unauthorized|http:InternalServerError {
        string|http:Unauthorized|error tenantCheck = requireValidTenant(xTenantId, xTenantProof, request);
        if tenantCheck is http:Unauthorized {
            return tenantCheck;
        }
        if tenantCheck is error {
            logInternalError("Unexpected failure during tenant proof verification", tenantCheck);
            return <http:InternalServerError>{
                body: {message: GENERIC_SERVER_ERROR_MESSAGE}
            };
        }

        string username = credentials.username;
        string password = credentials.password;

        AuthResult|error registrationResult = registerAccount(xTenantId, username, password);

        if registrationResult is AuthResult {
            return registrationResult;
        }

        string errorMessage = registrationResult.message();
        if errorMessage == "Password does not meet the minimum length requirement" {
            return <http:BadRequest>{
                body: {message: "Password must be at least 12 characters long."}
            };
        }

        if errorMessage == "Username is already taken" {
            return <http:BadRequest>{
                body: {message: "Username is already taken."}
            };
        }

        logInternalError("Unexpected failure during registration", registrationResult);
        return <http:InternalServerError>{
            body: {message: GENERIC_SERVER_ERROR_MESSAGE}
        };
    }

    // Authenticates an existing account under the authenticated tenant.
    // Unknown username and wrong password both produce an identical
    // response, with no timing tell.
    resource function post login(@http:Header {name: "X-Tenant-Id"} string xTenantId,
            @http:Header {name: "X-Tenant-Proof"} string? xTenantProof, http:Request request,
            @http:Payload Credentials credentials)
            returns AuthResult|http:Unauthorized|http:InternalServerError {
        string|http:Unauthorized|error tenantCheck = requireValidTenant(xTenantId, xTenantProof, request);
        if tenantCheck is http:Unauthorized {
            return tenantCheck;
        }
        if tenantCheck is error {
            logInternalError("Unexpected failure during tenant proof verification", tenantCheck);
            return <http:InternalServerError>{
                body: {message: GENERIC_SERVER_ERROR_MESSAGE}
            };
        }

        string username = credentials.username;
        string password = credentials.password;

        boolean|error authenticationResult = authenticateAccount(xTenantId, username, password);

        if authenticationResult is error {
            logInternalError("Unexpected failure during login", authenticationResult);
            return <http:InternalServerError>{
                body: {message: GENERIC_SERVER_ERROR_MESSAGE}
            };
        }

        if authenticationResult {
            return {message: "Login successful."};
        }

        return <http:Unauthorized>{
            body: {message: INVALID_LOGIN_MESSAGE}
        };
    }

    // Lists the usernames owned by the authenticated tenant.
    resource function get accounts(@http:Header {name: "X-Tenant-Id"} string xTenantId,
            @http:Header {name: "X-Tenant-Proof"} string? xTenantProof, http:Request request)
            returns AccountList|http:Unauthorized|http:InternalServerError {
        string|http:Unauthorized|error tenantCheck = requireValidTenant(xTenantId, xTenantProof, request);
        if tenantCheck is http:Unauthorized {
            return tenantCheck;
        }
        if tenantCheck is error {
            logInternalError("Unexpected failure during tenant proof verification", tenantCheck);
            return <http:InternalServerError>{
                body: {message: GENERIC_SERVER_ERROR_MESSAGE}
            };
        }

        string[] usernames = listTenantUsernames(xTenantId);
        return {usernames};
    }
}
