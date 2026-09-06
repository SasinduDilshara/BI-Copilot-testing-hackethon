import ballerina/http;
import ballerina/jwt;

listener http:Listener tokenIssuerListener = new (servicePort);

service /auth on tokenIssuerListener {

    // Authenticates a driver against the existing credentials store and, on success,
    // issues a short-lived signed JWT that downstream services can trust on their own.
    resource function post login(@http:Payload LoginRequest loginRequest)
            returns LoginResponse|http:Unauthorized|http:InternalServerError {
        DriverAuthResult|http:ClientError authResult = authenticateDriver(loginRequest);
        if authResult is http:ClientError {
            ErrorResponse errorResponse = {message: "Invalid username or password"};
            http:Unauthorized unauthorized = {body: errorResponse};
            return unauthorized;
        }

        string|jwt:Error token = issueDriverToken(authResult);
        if token is jwt:Error {
            ErrorResponse errorResponse = {message: "Failed to issue token"};
            http:InternalServerError internalServerError = {body: errorResponse};
            return internalServerError;
        }

        LoginResponse loginResponse = {
            token: token,
            expiresIn: tokenExpiryInSeconds
        };
        return loginResponse;
    }
}
