import ballerina/http;

configurable int servicePort = 8080;

service /auth on new http:Listener(servicePort) {

    // Registers a new admin account. Rejects short passwords and duplicate
    // usernames. Never echoes the password or any derived value.
    resource function post register(@http:Payload Credentials credentials) returns AuthResult|http:BadRequest|http:InternalServerError {
        string username = credentials.username;
        string password = credentials.password;

        AuthResult|error registrationResult = registerAccount(username, password);

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

    // Authenticates an existing admin account. Unknown username and wrong
    // password both produce an identical response, with no timing tell.
    resource function post login(@http:Payload Credentials credentials) returns AuthResult|http:Unauthorized|http:InternalServerError {
        string username = credentials.username;
        string password = credentials.password;

        boolean|error authenticationResult = authenticateAccount(username, password);

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
}
